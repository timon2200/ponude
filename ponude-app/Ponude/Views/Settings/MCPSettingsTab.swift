import SwiftUI

/// Settings pane for the local agent (MCP) API: switch it on, see its status,
/// and copy a ready-made MCP client configuration.
struct MCPSettingsTab: View {

    @AppStorage(MCPSettings.enabledKey) private var isEnabled = false
    @AppStorage(MCPSettings.portKey) private var port = MCPSettings.defaultPort

    @ObservedObject private var server = LocalAPIServer.shared

    @State private var showToken = false
    @State private var copied: String?

    var body: some View {
        Form {
            Section {
                Toggle("Dopusti agentima izradu ponuda", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, enabled in
                        MCPSettings.apply(enabled: enabled, port: port)
                    }

                Text("Pokreće lokalni poslužitelj na koji se spaja `ponude-mcp`. "
                     + "Dostupan je samo s ovog računala (127.0.0.1) i traži token ispod. "
                     + "Ponude nastaju u aplikaciji dok je otvorena — agenti nikad ne pišu izravno u bazu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(server.isRunning ? .green : .secondary)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .foregroundStyle(server.isRunning ? .primary : .secondary)
                    }
                }

                if let error = server.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Agenti (MCP)")
            }

            Section("Povezivanje") {
                LabeledContent("Port") {
                    TextField("", value: $port, format: .number.grouping(.never))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .disabled(isEnabled)
                        .help(isEnabled ? "Isključite poslužitelj za promjenu porta." : "")
                }

                LabeledContent("Token") {
                    HStack(spacing: 8) {
                        Text(showToken ? APIToken.current : String(repeating: "•", count: 24))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button(showToken ? "Sakrij" : "Prikaži") { showToken.toggle() }
                            .buttonStyle(.link)
                    }
                }

                HStack {
                    Button("Kopiraj MCP konfiguraciju") { copy(MCPSettings.clientConfigJSON(port: port), label: "config") }
                    Button("Novi token") { APIToken.regenerate(); showToken = false }
                    Spacer()
                    if copied != nil {
                        Label("Kopirano", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Section("Postavljanje") {
                Text("Dodajte konfiguraciju u svog MCP klijenta, npr. za Claude Code:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(MCPSettings.claudeCodeCommand(port: port))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

                Button("Kopiraj naredbu") { copy(MCPSettings.claudeCodeCommand(port: port), label: "command") }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520)
    }

    private var statusText: String {
        if server.isRunning { return "Sluša na 127.0.0.1:\(server.activePort)" }
        return isEnabled ? "Pokretanje…" : "Isključeno"
    }

    private func copy(_ string: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        copied = label
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = nil
        }
    }
}

// MARK: - Settings storage

enum MCPSettings {
    static let enabledKey = "mcpServerEnabled"
    static let portKey = "mcpServerPort"
    static let defaultPort = 8765

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static var port: Int {
        let stored = UserDefaults.standard.integer(forKey: portKey)
        return stored == 0 ? defaultPort : stored
    }

    /// Starts or stops the listener to match the stored preference.
    static func apply(enabled: Bool, port: Int) {
        if enabled {
            // Touching the token here means it exists on disk before any bridge
            // process tries to read it.
            _ = APIToken.current
            LocalAPIServer.shared.start(port: UInt16(clamping: port))
        } else {
            LocalAPIServer.shared.stop()
        }
    }

    /// Path to the bridge inside the running app bundle, so a config generated
    /// here keeps working wherever the user installed the app.
    static var bridgePath: String {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/ponude-mcp")
        if FileManager.default.fileExists(atPath: bundled.path) { return bundled.path }
        return "/Applications/Ponude.app/Contents/MacOS/ponude-mcp"
    }

    static func clientConfigJSON(port: Int) -> String {
        """
        {
          "mcpServers": {
            "ponude": {
              "command": "\(bridgePath)",
              "env": {
                "PONUDE_API_URL": "http://127.0.0.1:\(port)"
              }
            }
          }
        }
        """
    }

    static func claudeCodeCommand(port: Int) -> String {
        "claude mcp add ponude --env PONUDE_API_URL=http://127.0.0.1:\(port) -- \"\(bridgePath)\""
    }
}
