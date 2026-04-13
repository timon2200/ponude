import SwiftUI
import Sparkle

/// Wraps Sparkle's SPUStandardUpdaterController for SwiftUI integration.
/// Provides observable state for the "Check for Updates" menu item.
final class UpdaterViewModel: ObservableObject {
    private let updaterController: SPUStandardUpdaterController
    
    @Published var canCheckForUpdates = false
    
    init() {
        // Create the updater controller. 
        // startingUpdater: true means it will automatically check on launch.
        // updaterDelegate/userDriverDelegate: nil uses defaults.
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Observe the updater's canCheckForUpdates property
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    /// Triggers a manual update check (from menu item).
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}

/// A SwiftUI view that acts as the "Check for Updates…" menu item.
struct CheckForUpdatesView: View {
    @ObservedObject var updaterViewModel: UpdaterViewModel
    
    var body: some View {
        Button("Provjeri ažuriranja…") {
            updaterViewModel.checkForUpdates()
        }
        .disabled(!updaterViewModel.canCheckForUpdates)
    }
}
