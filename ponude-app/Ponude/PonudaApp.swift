import SwiftUI
import SwiftData
import Sparkle

@main
struct PonudaApp: App {
    @StateObject private var updaterViewModel = UpdaterViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            BusinessProfile.self,
            Client.self,
            Ponuda.self,
            PonudaStavka.self,
            Racun.self,
            RacunStavka.self
        ])
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nova ponuda") {
                    NotificationCenter.default.post(name: .createNewQuote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updaterViewModel: updaterViewModel)
            }
        }
        
        Settings {
            SettingsView()
                .modelContainer(for: [BusinessProfile.self, Client.self])
                .frame(minWidth: 500, minHeight: 400)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let createNewQuote = Notification.Name("createNewQuote")
}
