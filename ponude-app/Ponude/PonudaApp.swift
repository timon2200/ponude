import SwiftUI
import SwiftData
import SQLite3
import Sparkle

@main
struct PonudaApp: App {
    @StateObject private var updaterViewModel = UpdaterViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Shared Model Container

    /// A single shared container pinned to an explicit, stable SQLite path.
    /// Using a static let ensures only one container is ever created and both
    /// the main window and Settings window share the same store (no divergence).
    static let sharedModelContainer: ModelContainer = makeContainer()

    /// Builds the ModelContainer. Crashes loudly on failure so data loss is never silent.
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            BusinessProfile.self,
            Client.self,
            Ponuda.self,
            PonudaStavka.self,
            Racun.self,
            RacunStavka.self
        ])

        // Stable path: ~/Library/Application Support/hr.lotusrc.ponude/ponude.sqlite
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let storeDir = appSupport.appendingPathComponent("hr.lotusrc.ponude", isDirectory: true)

        // Ensure the directory exists before SwiftData tries to write
        do {
            try FileManager.default.createDirectory(
                at: storeDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            fatalError("[Ponude] ❌ Cannot create store directory at \(storeDir.path): \(error)")
        }

        let storeURL = storeDir.appendingPathComponent("ponude.sqlite")

        // ONE-TIME MIGRATION: if new store doesn't exist yet, copy from old Container location
        if !FileManager.default.fileExists(atPath: storeURL.path) {
            migrateOldContainerStore(to: storeURL)
        }

        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("[Ponude] ✅ SwiftData store at: \(storeURL.path)")
            return container
        } catch {
            // Do NOT fall back to an in-memory store — that silently loses all data.
            fatalError("[Ponude] ❌ Failed to open store at \(storeURL.path): \(error)")
        }
    }

    // MARK: - One-time Migration from old Container store

    /// Copies an older SwiftData store to the new explicit store path. Called only
    /// when the new path doesn't exist yet, so it runs exactly once per install.
    ///
    /// Both candidate locations are named `default.store` — the name SwiftData picks
    /// when no URL is given — which is *not* app-specific. `~/Library/Application
    /// Support/default.store` in particular is shared by every unsandboxed SwiftData
    /// app on the machine, so it may well belong to something else entirely. Adopting
    /// a foreign store looks like success and then presents an empty app, because
    /// SwiftData lightweight-migrates the mismatched schema into empty tables.
    /// Every candidate is therefore verified to hold Ponude's own tables first, and
    /// the sandbox container (which can only ever be ours) is preferred.
    private static func migrateOldContainerStore(to newURL: URL) {
        let fm = FileManager.default

        // Sandbox container first — that path is exclusive to this bundle ID.
        let sandboxStore = URL(fileURLWithPath: NSHomeDirectory())
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Containers/hr.lotusrc.ponude/Data/Library/Application Support/default.store")

        // Shared unsandboxed default location — used by any SwiftData app.
        let sharedStore = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("default.store")

        for oldURL in [sandboxStore, sharedStore] {
            guard fm.fileExists(atPath: oldURL.path) else { continue }
            guard storeContainsPonudeData(at: oldURL) else {
                print("[Ponude] ⏭ Skipping \(oldURL.path) — not a Ponude store.")
                continue
            }

            do {
                try fm.copyItem(at: oldURL, to: newURL)
                print("[Ponude] ✅ Migrated store from \(oldURL.path) to \(newURL.path)")
            } catch {
                print("[Ponude] ⚠️ Could not copy store: \(error). Starting fresh.")
                return
            }

            // Copy the WAL and SHM sidecars too — the WAL holds the most recent
            // writes and the store is incomplete without it.
            let oldDir = oldURL.deletingLastPathComponent()
            let newDir = newURL.deletingLastPathComponent()
            for suffix in ["-wal", "-shm"] {
                let oldSidecar = oldDir.appendingPathComponent(oldURL.lastPathComponent + suffix)
                let newSidecar = newDir.appendingPathComponent(newURL.lastPathComponent + suffix)
                if fm.fileExists(atPath: oldSidecar.path) {
                    try? fm.copyItem(at: oldSidecar, to: newSidecar)
                    print("[Ponude] ✅ Migrated \(suffix) sidecar")
                }
            }
            return // Migrated from the first store that is actually ours
        }

        print("[Ponude] ℹ️ No old Ponude store found to migrate. Starting fresh.")
    }

    /// True when the SQLite file at `url` holds this app's Core Data tables.
    /// Reads the schema directly — opening it with SwiftData would migrate it,
    /// which is exactly what must not happen to a store belonging to another app.
    private static func storeContainsPonudeData(at url: URL) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return false }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        let sql = "SELECT count(*) FROM sqlite_master WHERE type='table' AND name IN ('ZPONUDA','ZBUSINESSPROFILE')"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else { return false }
        return sqlite3_column_int(statement, 0) == 2
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(PonudaApp.sharedModelContainer)
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
                // Re-use the same container so Settings edits are immediately visible
                // in the main window and persisted to the same store.
                .modelContainer(PonudaApp.sharedModelContainer)
                .frame(minWidth: 500, minHeight: 400)
        }
    }
}

// MARK: - App Delegate — WAL Checkpoint on Quit

/// Forces a SQLite WAL checkpoint before the process exits.
///
/// SwiftData (CoreData underneath) uses SQLite in WAL mode: every save appends
/// to a `-wal` file, which is only merged back into the main `.sqlite` on a
/// checkpoint. If the app is force-quit or crashes before a checkpoint, any
/// data in the WAL *can* be recovered by SQLite on next open — but if the WAL
/// file itself is deleted or the container is recreated, it is lost.
/// Saving explicitly on termination guarantees a clean checkpoint every time.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillTerminate(_ notification: Notification) {
        saveOnQuit()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        saveOnQuit()
        return .terminateNow
    }

    private func saveOnQuit() {
        Persistence.save(PonudaApp.sharedModelContainer.mainContext, "quit")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let createNewQuote = Notification.Name("createNewQuote")
}
