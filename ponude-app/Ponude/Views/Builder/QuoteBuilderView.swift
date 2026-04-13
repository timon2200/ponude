import SwiftUI
import SwiftData

/// The main quote builder — split-pane with editor on left and live A4 preview on right.
struct QuoteBuilderView: View {
    let businessProfile: BusinessProfile
    let existingPonuda: Ponuda?
    let onDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Query(sort: \Ponuda.broj, order: .reverse) private var allPonude: [Ponuda]
    
    @State private var state: QuoteBuilderState
    @State private var showClientSelector = false
    @State private var showExportPanel = false
    @State private var quoteNumber: Int
    
    init(businessProfile: BusinessProfile, existingPonuda: Ponuda?, onDismiss: @escaping () -> Void) {
        self.businessProfile = businessProfile
        self.existingPonuda = existingPonuda
        self.onDismiss = onDismiss
        
        let defaultCity = businessProfile.city
        _state = State(initialValue: QuoteBuilderState(ponuda: existingPonuda, defaultMjesto: defaultCity))
        _quoteNumber = State(initialValue: existingPonuda?.broj ?? 0)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left: Editor Panel
            editorPanel
            
            // MARK: - Right: Live Preview
            previewPanel
        }
        .navigationTitle("")
        .toolbar(.hidden)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            if quoteNumber == 0 {
                let profilePonude = allPonude.filter { $0.businessProfile?.id == businessProfile.id }
                quoteNumber = (profilePonude.first?.broj ?? 0) + 1
            }
        }
        .sheet(isPresented: $showClientSelector) {
            ClientSelectorView(selectedClient: $state.selectedClient)
                .frame(minWidth: 500, minHeight: 400)
        }
    }
    
    // MARK: - Editor Panel
    
    private var editorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                editorHeader
                
                // Client section
                clientSection
                
                // Quote details
                detailsSection
                
                // Service items — the core editing area
                serviceItemsSection
                
                // Notes
                notesSection
                
                // Actions
                actionsSection
                
                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .frame(minWidth: 380, idealWidth: 440, maxWidth: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Preview Panel
    
    private var previewPanel: some View {
        ZStack {
            DesignTokens.pageBackground
            
            DebouncedPreviewWrapper(
                businessProfile: businessProfile,
                state: state,
                quoteNumber: quoteNumber
            )
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Editor Sections
    
    private var editorHeader: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(existingPonuda != nil ? "Uredi ponudu" : "Nova ponuda")
                    .font(.system(size: 22, weight: .bold))
                Text(businessProfile.shortName)
                    .font(.system(size: 13))
                    .foregroundStyle(brandAccent)
            }
            
            Spacer()
            
            Button("Zatvori", systemImage: "xmark.circle.fill") {
                onDismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
    
    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Klijent", systemImage: "person.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            
            if let client = state.selectedClient {
                // Selected client card
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(brandAccent.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Text(String(client.name.prefix(1)))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(brandAccent)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                        if !client.fullAddress.isEmpty {
                            Text(client.fullAddress)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        showClientSelector = true
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(DesignTokens.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
            } else {
                Button {
                    showClientSelector = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Odaberi klijenta")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Detalji", systemImage: "info.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Broj").font(.system(size: 10)).foregroundStyle(.secondary)
                        Text("#\(quoteNumber)")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(brandAccent)
                    }
                    .frame(width: 70, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Datum").font(.system(size: 10)).foregroundStyle(.secondary)
                        DatePicker("", selection: $state.datum, displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "hr_HR"))
                    }
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mjesto").font(.system(size: 10)).foregroundStyle(.secondary)
                        TextField("npr. Varaždin", text: $state.mjesto)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rok (dana)").font(.system(size: 10)).foregroundStyle(.secondary)
                        TextField("30", text: $state.rokValjanosti)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .frame(width: 60)
                    }
                }
            }
            .padding(12)
            .background(DesignTokens.cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
        }
    }
    
    private var serviceItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Stavke", systemImage: "list.bullet")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(state.formattedUkupno) €")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(brandAccent)
            }
            
            VStack(spacing: 0) {
                ForEach(Array(state.stavke.enumerated()), id: \.element.id) { index, stavka in
                    ServiceItemRow(
                        item: stavka,
                        index: index + 1,
                        onDelete: {
                            state.removeStavka(stavka)
                        }
                    )
                    
                    if index < state.stavke.count - 1 {
                        Divider().padding(.horizontal, 12)
                    }
                }
                
                // Add item button
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        state.addStavka()
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(brandAccent)
                        Text("Dodaj stavku")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .background(DesignTokens.cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Napomene", systemImage: "note.text")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            
            TextEditor(text: $state.napomena)
                .font(.system(size: 12))
                .frame(height: 60)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(DesignTokens.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
        }
    }
    
    private var actionsSection: some View {
        HStack(spacing: 12) {
            Button {
                saveQuote()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Spremi")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(brandAccent)
            .disabled(!state.isValid)
            
            Button {
                saveQuote()
                exportPDF()
            } label: {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("Izvezi PDF")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(!state.isValid)
        }
        .overlay(alignment: .top) {
            if state.showSaveSuccess {
                Text("✓ Ponuda spremljena")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(DesignTokens.statusAccepted, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .offset(y: -36)
            }
        }
    }
    
    // MARK: - Save Logic
    
    private func saveQuote() {
        let ponuda: Ponuda
        
        if let existing = existingPonuda {
            ponuda = existing
        } else {
            ponuda = Ponuda(broj: quoteNumber)
            modelContext.insert(ponuda)
        }
        
        ponuda.datum = state.datum
        ponuda.mjesto = state.mjesto
        ponuda.rokValjanosti = state.rokValjanostiDays
        ponuda.napomena = state.napomena
        ponuda.businessProfile = businessProfile
        ponuda.client = state.selectedClient
        ponuda.updatedAt = Date()
        
        // Remove old stavke
        for stavka in ponuda.stavke {
            modelContext.delete(stavka)
        }
        
        // Add new stavke
        for (index, item) in state.stavke.enumerated() {
            let stavka = PonudaStavka(
                redniBroj: index + 1,
                naziv: item.naziv,
                opis: item.opis,
                kolicina: item.kolicinaDecimal,
                cijena: item.cijenaDecimal
            )
            stavka.ponuda = ponuda
            modelContext.insert(stavka)
        }
        
        try? modelContext.save()
        
        withAnimation {
            state.showSaveSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                state.showSaveSuccess = false
            }
        }
    }
    
    // MARK: - PDF Export
    
    private func exportPDF() {
        let generator = PDFGenerator()
        generator.exportQuote(
            businessProfile: businessProfile,
            client: state.selectedClient,
            ponudaBroj: quoteNumber,
            datum: state.datum,
            mjesto: state.mjesto,
            stavke: state.stavke,
            ukupno: state.ukupno,
            napomena: state.napomena,
            rokValjanosti: state.rokValjanostiDays
        )
    }
}
