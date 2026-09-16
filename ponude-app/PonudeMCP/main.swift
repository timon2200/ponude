import Foundation

// ponude-mcp — an MCP stdio server that fronts the Ponude app's local HTTP API.
//
// It holds no state and touches no database: every tool call is forwarded to
// http://127.0.0.1:<port> inside the running app, which stays the single writer
// of the SQLite store. That means quotes an agent creates appear in the app's
// window immediately, and there is no second process that could corrupt the
// store or lose writes.
//
// Configuration (both optional):
//   PONUDE_API_URL    default http://127.0.0.1:8765
//   PONUDE_API_TOKEN  default: read from the app's api-token.txt

// MARK: - Configuration

enum Config {
    static let baseURL: URL = {
        let raw = ProcessInfo.processInfo.environment["PONUDE_API_URL"] ?? "http://127.0.0.1:8765"
        return URL(string: raw) ?? URL(string: "http://127.0.0.1:8765")!
    }()

    static let token: String = {
        if let fromEnv = ProcessInfo.processInfo.environment["PONUDE_API_TOKEN"], !fromEnv.isEmpty {
            return fromEnv
        }
        let tokenFile = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("hr.lotusrc.ponude/api-token.txt")
        let contents = (try? String(contentsOf: tokenFile, encoding: .utf8)) ?? ""
        return contents.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
}

// MARK: - HTTP client

enum APIError: Error, LocalizedError {
    case appNotRunning
    case unauthorized
    case server(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .appNotRunning:
            return "The Ponude app is not running, or its local API is switched off. "
                 + "Open Ponude and enable the agent API under Settings → Agenti (MCP)."
        case .unauthorized:
            return "The API token was rejected. Copy the current token from Settings → Agenti (MCP)."
        case .server(let message):
            return message
        case .transport(let message):
            return "Could not reach the Ponude app: \(message)"
        }
    }
}

/// Synchronous request/response — this process is a serial stdio loop, so there
/// is nothing to gain from concurrency and a semaphore keeps ordering obvious.
func callAPI(_ method: String, _ path: String, body: [String: Any]? = nil) throws -> Any {
    // Built by hand rather than with `appendingPathComponent`, which would
    // percent-escape the '?' and turn the query string into part of the path.
    let base = Config.baseURL.absoluteString.hasSuffix("/")
        ? String(Config.baseURL.absoluteString.dropLast())
        : Config.baseURL.absoluteString
    guard let url = URL(string: base + "/" + path) else {
        throw APIError.transport("Could not build a URL for /\(path)")
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(Config.token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 30

    if let body {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }

    var result: Result<(Data, HTTPURLResponse), Error>?
    let semaphore = DispatchSemaphore(value: 0)

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
            result = .failure(error)
        } else if let data, let response = response as? HTTPURLResponse {
            result = .success((data, response))
        } else {
            result = .failure(APIError.transport("empty response"))
        }
        semaphore.signal()
    }.resume()

    semaphore.wait()

    switch result {
    case .failure(let error):
        if let urlError = error as? URLError,
           [.cannotConnectToHost, .networkConnectionLost, .cannotFindHost].contains(urlError.code) {
            throw APIError.appNotRunning
        }
        throw APIError.transport(error.localizedDescription)

    case .success(let (data, response)):
        let payload = (try? JSONSerialization.jsonObject(with: data)) ?? [:]
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 { throw APIError.unauthorized }
            let message = (payload as? [String: Any])?["error"] as? String ?? "HTTP \(response.statusCode)"
            throw APIError.server(message)
        }
        return payload

    case .none:
        throw APIError.transport("no result")
    }
}

// MARK: - Tool definitions

let toolDefinitions: [[String: Any]] = [
    [
        "name": "list_business_profiles",
        "description": "List the business profiles (issuers) configured in Ponude. "
            + "Every quote is issued by one of these, and the profile decides both the quote numbering sequence and the PDF design. "
            + "Call this first when you do not know which profile to use.",
        "inputSchema": ["type": "object", "properties": [:] as [String: Any]]
    ],
    [
        "name": "search_clients",
        "description": "Search saved clients by name, OIB, city, or contact person. "
            + "Multi-word queries match loosely, so 'turis kop' finds 'Turistička zajednica grada Koprivnice'. "
            + "Omit the query to list every client.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "Search terms; all words must match."]
            ]
        ]
    ],
    [
        "name": "create_client",
        "description": "Create a client. If a client with the same OIB already exists it is returned untouched "
            + "rather than duplicated (the response's 'created' field says which happened).",
        "inputSchema": [
            "type": "object",
            "properties": [
                "name": ["type": "string", "description": "Legal name of the company."],
                "oib": ["type": "string", "description": "Croatian tax ID (11 digits)."],
                "address": ["type": "string"],
                "city": ["type": "string"],
                "zip_code": ["type": "string"],
                "contact_person": ["type": "string"],
                "email": ["type": "string"],
                "phone": ["type": "string"]
            ],
            "required": ["name"]
        ]
    ],
    [
        "name": "create_ponuda",
        "description": "Create a quote (ponuda) in Ponude. It is saved to the app's store and appears in the "
            + "dashboard immediately. The quote number is assigned automatically as the next one in the chosen "
            + "profile's sequence. Amounts are in EUR and no VAT is added — the profiles are VAT-exempt.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "profile": [
                    "type": "string",
                    "description": "Which business profile issues the quote — its name, short name, OIB, or id from list_business_profiles."
                ],
                "client_id": ["type": "string", "description": "Client id from search_clients or create_client. Preferred."],
                "client_oib": ["type": "string", "description": "Alternative to client_id: match the client by OIB."],
                "client_name": ["type": "string", "description": "Last resort: match by name. Rejected if it matches more than one client."],
                "stavke": [
                    "type": "array",
                    "description": "Line items, in the order they should appear.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "naziv": ["type": "string", "description": "Service name, e.g. 'Snimanje promotivnog videa'."],
                            "opis": ["type": "string", "description": "Optional detail line shown under the name."],
                            "kolicina": ["type": "number", "description": "Quantity. Defaults to 1."],
                            "cijena": ["type": "number", "description": "Unit price in EUR."]
                        ],
                        "required": ["naziv", "cijena"]
                    ]
                ],
                "datum": ["type": "string", "description": "Issue date as YYYY-MM-DD. Defaults to today."],
                "mjesto": ["type": "string", "description": "Place of issue. Defaults to the profile's city."],
                "rok_valjanosti": ["type": "integer", "description": "Validity in days. Defaults to 30."],
                "napomena": ["type": "string", "description": "Free-text note printed on the quote."],
                "status": ["type": "string", "description": "Nacrt, Poslano, Prihvaćeno, or Odbijeno. Defaults to Nacrt."],
                "jezik": ["type": "string", "description": "PDF language: 'hr' (default) or 'en' — translates the template chrome (headings, table columns, totals)."]
            ],
            "required": ["profile", "stavke"]
        ]
    ],
    [
        "name": "list_ponude",
        "description": "List existing quotes, newest number first, with client, total, and status.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "profile": ["type": "string", "description": "Optional: only quotes issued by this business profile."],
                "limit": ["type": "integer", "description": "Maximum number to return. Defaults to 50."]
            ]
        ]
    ],
    [
        "name": "get_ponuda",
        "description": "Fetch one quote in full, including every line item.",
        "inputSchema": [
            "type": "object",
            "properties": ["id": ["type": "string", "description": "Quote id from create_ponuda or list_ponude."]],
            "required": ["id"]
        ]
    ],
    [
        "name": "export_ponuda_pdf",
        "description": "Render a quote to a PDF file using its profile's design and return the path. "
            + "Defaults to the user's Downloads folder.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "Quote id."],
                "path": ["type": "string", "description": "Optional absolute destination path ending in .pdf."]
            ],
            "required": ["id"]
        ]
    ],
    [
        "name": "update_ponuda",
        "description": "Update an existing quote. Only the fields passed are changed; everything omitted stays as it is. "
            + "Passing 'stavke' replaces the whole set of line items. Returns the updated quote in full.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "Quote id from list_ponude or get_ponuda."],
                "client_id": ["type": "string", "description": "Reassign the quote to this client (also: client_oib, client_name)."],
                "client_oib": ["type": "string"],
                "client_name": ["type": "string"],
                "stavke": [
                    "type": "array",
                    "description": "Full replacement set of line items, in the order they should appear.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "naziv": ["type": "string", "description": "Service name."],
                            "opis": ["type": "string", "description": "Optional detail line shown under the name."],
                            "kolicina": ["type": "number", "description": "Quantity. Defaults to 1."],
                            "cijena": ["type": "number", "description": "Unit price in EUR."]
                        ],
                        "required": ["naziv", "cijena"]
                    ]
                ],
                "datum": ["type": "string", "description": "Issue date as YYYY-MM-DD."],
                "mjesto": ["type": "string", "description": "Place of issue."],
                "rok_valjanosti": ["type": "integer", "description": "Validity in days."],
                "napomena": ["type": "string", "description": "Free-text note printed on the quote."],
                "status": ["type": "string", "description": "Nacrt, Poslano, Prihvaćeno, or Odbijeno."],
                "jezik": ["type": "string", "description": "PDF language: 'hr' or 'en'."]
            ],
            "required": ["id"]
        ]
    ],
    [
        "name": "delete_ponuda",
        "description": "Delete a quote and its line items permanently. There is no undo.",
        "inputSchema": [
            "type": "object",
            "properties": ["id": ["type": "string", "description": "Quote id from list_ponude or get_ponuda."]],
            "required": ["id"]
        ]
    ]
]

// MARK: - Tool dispatch

func callTool(name: String, arguments: [String: Any]) throws -> Any {
    switch name {
    case "list_business_profiles":
        return try callAPI("GET", "profiles")

    case "search_clients":
        let query = (arguments["query"] as? String) ?? ""
        let escaped = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return try callAPI("GET", "clients" + (escaped.isEmpty ? "" : "?q=\(escaped)"))

    case "create_client":
        return try callAPI("POST", "clients", body: arguments)

    case "create_ponuda":
        return try callAPI("POST", "ponude", body: arguments)

    case "list_ponude":
        var query: [String] = []
        if let profile = arguments["profile"] as? String, !profile.isEmpty {
            query.append("profile=" + (profile.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""))
        }
        if let limit = arguments["limit"] as? Int {
            query.append("limit=\(limit)")
        }
        return try callAPI("GET", "ponude" + (query.isEmpty ? "" : "?" + query.joined(separator: "&")))

    case "get_ponuda":
        guard let id = arguments["id"] as? String else { throw APIError.server("Missing 'id'") }
        return try callAPI("GET", "ponude/\(id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? id)")

    case "export_ponuda_pdf":
        guard let id = arguments["id"] as? String else { throw APIError.server("Missing 'id'") }
        var body: [String: Any] = [:]
        if let path = arguments["path"] as? String { body["path"] = path }
        return try callAPI("POST", "ponude/\(id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? id)/pdf", body: body)

    case "update_ponuda":
        guard let id = arguments["id"] as? String else { throw APIError.server("Missing 'id'") }
        var body = arguments
        body.removeValue(forKey: "id")
        return try callAPI("PUT", "ponude/\(id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? id)", body: body)

    case "delete_ponuda":
        guard let id = arguments["id"] as? String else { throw APIError.server("Missing 'id'") }
        return try callAPI("DELETE", "ponude/\(id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? id)")

    default:
        throw APIError.server("Unknown tool '\(name)'")
    }
}

// MARK: - JSON-RPC plumbing

let stdout = FileHandle.standardOutput
let outputLock = NSLock()

func respond(_ message: [String: Any]) {
    guard var data = try? JSONSerialization.data(withJSONObject: message, options: [.withoutEscapingSlashes]) else { return }
    data.append(0x0A) // MCP stdio framing is one JSON object per line.
    outputLock.lock()
    stdout.write(data)
    outputLock.unlock()
}

func reply(id: Any, result: [String: Any]) {
    respond(["jsonrpc": "2.0", "id": id, "result": result])
}

func reply(id: Any, code: Int, message: String) {
    respond(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
}

/// Tool output goes back as text; JSON keeps it unambiguous for the model.
func textContent(_ value: Any) -> [String: Any] {
    let text: String
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
       let string = String(data: data, encoding: .utf8) {
        text = string
    } else {
        text = String(describing: value)
    }
    return ["content": [["type": "text", "text": text]]]
}

let supportedProtocolVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]

func handle(_ message: [String: Any]) {
    let method = message["method"] as? String ?? ""
    let id = message["id"]

    switch method {
    case "initialize":
        let requested = (message["params"] as? [String: Any])?["protocolVersion"] as? String
        let version = supportedProtocolVersions.contains(requested ?? "") ? requested! : supportedProtocolVersions[0]
        reply(id: id ?? NSNull(), result: [
            "protocolVersion": version,
            "capabilities": ["tools": [:] as [String: Any]],
            "serverInfo": ["name": "ponude", "version": "1.0.0"],
            "instructions": "Creates, updates, and deletes quotes (ponude) in the Ponude macOS app. "
                + "The app must be running with its agent API enabled. "
                + "Typical flow: list_business_profiles → search_clients → create_ponuda → export_ponuda_pdf. "
                + "update_ponuda changes only the fields you pass; delete_ponuda is permanent."
        ])

    case "notifications/initialized", "notifications/cancelled":
        break // Notifications carry no id and take no response.

    case "ping":
        reply(id: id ?? NSNull(), result: [:])

    case "tools/list":
        reply(id: id ?? NSNull(), result: ["tools": toolDefinitions])

    case "tools/call":
        let params = message["params"] as? [String: Any] ?? [:]
        let name = params["name"] as? String ?? ""
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        do {
            let result = try callTool(name: name, arguments: arguments)
            reply(id: id ?? NSNull(), result: textContent(result))
        } catch {
            // Tool failures are reported in-band so the model can read the
            // reason and retry, rather than as a protocol-level error.
            var payload = textContent(["error": error.localizedDescription])
            payload["isError"] = true
            reply(id: id ?? NSNull(), result: payload)
        }

    default:
        if let id {
            reply(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }
}

// MARK: - Read loop

while let line = readLine(strippingNewline: true) {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { continue }
    guard let data = trimmed.data(using: .utf8),
          let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        continue
    }
    handle(message)
}
