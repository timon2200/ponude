import SwiftUI

/// Wraps `QuotePreviewView` with a 300ms debounce so the heavy A4 preview
/// doesn't re-render on every keystroke — only after the user pauses typing.
struct DebouncedPreviewWrapper: View {
    let businessProfile: BusinessProfile
    let state: QuoteBuilderState
    let quoteNumber: Int
    
    // Debounce interval
    private let debounceInterval: TimeInterval = 0.3
    
    // Local snapshot that only updates after debounce
    @State private var snapshotClient: Client?
    @State private var snapshotBroj: Int = 0
    @State private var snapshotDatum: Date = Date()
    @State private var snapshotMjesto: String = ""
    @State private var snapshotStavke: [StavkaEditItem] = []
    @State private var snapshotUkupno: Decimal = 0
    @State private var snapshotNapomena: String = ""
    @State private var snapshotRok: Int = 30
    @State private var debounceTask: Task<Void, Never>?
    @State private var hasInitialized = false
    
    var body: some View {
        QuotePreviewView(
            businessProfile: businessProfile,
            client: snapshotClient,
            ponudaBroj: snapshotBroj,
            datum: snapshotDatum,
            mjesto: snapshotMjesto,
            stavke: snapshotStavke,
            ukupno: snapshotUkupno,
            napomena: snapshotNapomena,
            rokValjanosti: snapshotRok
        )
        .onAppear {
            if !hasInitialized {
                takeSnapshot()
                hasInitialized = true
            }
        }
        .onChange(of: state.changeToken) {
            scheduleSnapshot()
        }
    }
    
    private func scheduleSnapshot() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            takeSnapshot()
        }
    }
    
    private func takeSnapshot() {
        snapshotClient = state.selectedClient
        snapshotBroj = quoteNumber
        snapshotDatum = state.datum
        snapshotMjesto = state.mjesto
        snapshotStavke = state.stavke
        snapshotUkupno = state.ukupno
        snapshotNapomena = state.napomena
        snapshotRok = state.rokValjanostiDays
    }
}
