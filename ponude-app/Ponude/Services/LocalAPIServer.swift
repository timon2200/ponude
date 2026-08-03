import Foundation
import Network
import SwiftData
import os

/// A loopback-only HTTP API that lets external tools (in practice: the
/// `ponude-mcp` bridge, and through it any MCP-speaking agent) read and create
/// quotes in the running app.
///
/// Why an in-app server rather than a standalone process that opens the store
/// directly: the SQLite store must have exactly one writer. A second process
/// writing to `ponude.sqlite` behind the app's back would fight the app's own
/// context, and the running UI would keep showing stale data until relaunch.
/// Routing everything through the app means the app stays the single writer,
/// `@Query` views refresh live, and every write still goes through
/// `Persistence.save` so a failure is logged rather than swallowed.
///
/// Security posture: the listener is pinned to 127.0.0.1 (never reachable off
/// the machine) and every route except `/health` requires the bearer token from
/// `APIToken.current`.
final class LocalAPIServer: ObservableObject, @unchecked Sendable {

    static let shared = LocalAPIServer()

    static let log = Logger(subsystem: "hr.lotusrc.ponude", category: "api")

    @Published private(set) var isRunning = false
    @Published private(set) var activePort: UInt16 = 0
    /// Non-nil when the last start attempt failed — surfaced in Settings.
    @Published private(set) var lastError: String?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "hr.lotusrc.ponude.api", qos: .userInitiated)

    /// Requests larger than this are rejected outright.
    private static let maxBodyBytes = 4 * 1024 * 1024

    private init() {}

    // MARK: - Lifecycle

    func start(port: UInt16) {
        stop()

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        // Binding the local endpoint to loopback is what keeps this off the network.
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .init(rawValue: port)!)

        do {
            let listener = try NWListener(using: params)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.publish(running: true, port: port, error: nil)
                    Self.log.info("Local API listening on 127.0.0.1:\(port, privacy: .public)")
                    print("[Ponude] 🔌 Local API listening on http://127.0.0.1:\(port)")
                case .failed(let error), .waiting(let error):
                    self?.publish(running: false, port: 0, error: error.localizedDescription)
                    Self.log.error("Local API failed: \(error.localizedDescription, privacy: .public)")
                case .cancelled:
                    self?.publish(running: false, port: 0, error: nil)
                default:
                    break
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            publish(running: false, port: 0, error: error.localizedDescription)
            Self.log.error("Could not open listener: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        publish(running: false, port: 0, error: nil)
    }

    private func publish(running: Bool, port: UInt16, error: String?) {
        DispatchQueue.main.async {
            self.isRunning = running
            self.activePort = port
            self.lastError = error
        }
    }

    // MARK: - Connection handling

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            var buffer = buffer
            if let data { buffer.append(data) }

            if error != nil {
                connection.cancel()
                return
            }

            if buffer.count > Self.maxBodyBytes {
                self.send(.error(413, "Request too large"), on: connection)
                return
            }

            switch HTTPRequest.parse(buffer) {
            case .incomplete:
                if isComplete {
                    connection.cancel()
                } else {
                    self.receive(on: connection, buffer: buffer)
                }
            case .malformed:
                self.send(.error(400, "Malformed request"), on: connection)
            case .request(let request):
                Task { @MainActor in
                    let response = await Router.handle(request)
                    self.send(response, on: connection)
                }
            }
        }
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.serialized(), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

// MARK: - Minimal HTTP types

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data

    enum ParseResult {
        case incomplete
        case malformed
        case request(HTTPRequest)
    }

    var json: [String: Any] {
        guard !body.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return [:] }
        return object
    }

    var bearerToken: String? {
        guard let header = headers["authorization"], header.lowercased().hasPrefix("bearer ") else { return nil }
        return String(header.dropFirst(7)).trimmingCharacters(in: .whitespaces)
    }

    /// Splits a request into its parts, or reports that more bytes are needed.
    /// Only enough of HTTP/1.1 is implemented to serve a local JSON API.
    static func parse(_ buffer: Data) -> ParseResult {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerEnd = buffer.range(of: separator) else { return .incomplete }

        guard let headerText = String(data: buffer[..<headerEnd.lowerBound], encoding: .utf8) else {
            return .malformed
        }

        var lines = headerText.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return .malformed }

        let requestLine = lines.removeFirst().components(separatedBy: " ")
        guard requestLine.count >= 2 else { return .malformed }

        let method = requestLine[0].uppercased()
        let target = requestLine[1]

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let expectedLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = headerEnd.upperBound
        let available = buffer.count - bodyStart
        guard available >= expectedLength else { return .incomplete }

        let body = buffer.subdata(in: bodyStart..<(bodyStart + expectedLength))

        // Split path from query string.
        var path = target
        var query: [String: String] = [:]
        if let questionMark = target.firstIndex(of: "?") {
            path = String(target[..<questionMark])
            let rawQuery = String(target[target.index(after: questionMark)...])
            for pair in rawQuery.components(separatedBy: "&") where !pair.isEmpty {
                let parts = pair.components(separatedBy: "=")
                let key = parts[0].removingPercentEncoding ?? parts[0]
                let value = parts.count > 1
                    ? (parts[1].replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? parts[1])
                    : ""
                query[key] = value
            }
        }

        return .request(HTTPRequest(
            method: method,
            path: path,
            query: query,
            headers: headers,
            body: body
        ))
    }
}

struct HTTPResponse {
    let status: Int
    let body: Data

    static func json(_ object: Any, status: Int = 200) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]))
            ?? Data("{}".utf8)
        return HTTPResponse(status: status, body: data)
    }

    static func error(_ status: Int, _ message: String) -> HTTPResponse {
        .json(["error": message], status: status)
    }

    func serialized() -> Data {
        let reason: String
        switch status {
        case 200: reason = "OK"
        case 201: reason = "Created"
        case 400: reason = "Bad Request"
        case 401: reason = "Unauthorized"
        case 404: reason = "Not Found"
        case 413: reason = "Payload Too Large"
        case 500: reason = "Internal Server Error"
        default:  reason = "Status"
        }

        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: application/json; charset=utf-8\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"

        var data = Data(head.utf8)
        data.append(body)
        return data
    }
}
