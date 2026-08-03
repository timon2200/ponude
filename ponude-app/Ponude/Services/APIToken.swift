import Foundation
import Security

/// The shared secret between the app and the `ponude-mcp` bridge.
///
/// It is written next to the store as `api-token.txt` with owner-only
/// permissions, so the bridge can pick it up without the token having to be
/// pasted into an MCP config file in plain text. An explicit
/// `PONUDE_API_TOKEN` in the environment still wins on the bridge side.
enum APIToken {

    static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("hr.lotusrc.ponude", isDirectory: true)
            .appendingPathComponent("api-token.txt")
    }

    /// The active token, generating and persisting one on first use.
    static var current: String {
        if let existing = try? String(contentsOf: fileURL, encoding: .utf8) {
            let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return regenerate()
    }

    /// Issues a fresh token, invalidating the old one.
    @discardableResult
    static func regenerate() -> String {
        let token = randomToken()
        write(token)
        return token
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        // A CSPRNG matters here: the token is the only thing standing between a
        // local process and the ability to write to the user's quote store.
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func write(_ token: String) {
        let url = fileURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try token.write(to: url, atomically: true, encoding: .utf8)
            // 0o600 — readable only by the user running the app.
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            LocalAPIServer.log.error("Could not persist API token: \(error.localizedDescription, privacy: .public)")
        }
    }
}
