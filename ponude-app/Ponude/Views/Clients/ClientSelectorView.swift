import SwiftUI
import SwiftData

/// A sheet-presented client selector with local search and Sudreg API integration.
/// Automatically searches Sudreg as you type (debounced) for seamless autofill.
struct ClientSelectorView: View {
    @Binding var selectedClient: Client?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Client.name) private var localClients: [Client]
    
    @State private var searchText = ""
    @State private var sudregResults: [SudregSubject] = []
    @State private var builtinResults: [FrequentClient] = []
    @State private var isSearchingSudreg = false
    @State private var showAddClientForm = false
    @State private var newClient = NewClientData()
    @State private var searchTask: Task<Void, Never>?
    @State private var sudregError: String?
    @State private var sudregConfigured = true
    
    private let sudregService = SudregService()
    private let frequentClientsService = FrequentClientsService.shared
    
    private var filteredLocal: [Client] {
        if searchText.isEmpty { return localClients }
        return localClients.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.oib.contains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Odaberi klijenta")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Traži po nazivu ili OIB-u...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        triggerSudregSearch()
                    }
                
                if isSearchingSudreg {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        sudregResults = []
                        builtinResults = []
                        sudregError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            
            // Sudreg status indicator
            if !sudregConfigured {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("Sudreg API nije konfiguriran — postavke → Sudreg API")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.06))
            }
            
            Divider()
            
            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Local clients
                    if !filteredLocal.isEmpty {
                        sectionHeader("Spremljeni klijenti", icon: "person.2.fill")
                        
                        ForEach(filteredLocal) { client in
                            ClientRow(
                                name: client.name,
                                subtitle: client.fullAddress,
                                oib: client.oib,
                                source: .local,
                                action: {
                                    selectedClient = client
                                    dismiss()
                                }
                            )
                        }
                    }
                    
                    // Built-in public institutions
                    if !builtinResults.isEmpty {
                        sectionHeader("Javne institucije — autofill", icon: "building.2.fill")
                        
                        ForEach(builtinResults) { client in
                            ClientRow(
                                name: client.name,
                                subtitle: [client.address, client.zipCode, client.city].filter { !$0.isEmpty }.joined(separator: ", "),
                                oib: client.oib,
                                source: .builtin,
                                action: {
                                    saveAndSelectBuiltinClient(client)
                                }
                            )
                        }
                    }
                    
                    // Sudreg results
                    if !sudregResults.isEmpty {
                        sectionHeader("Sudski registar — autofill", icon: "building.columns.fill")
                        
                        ForEach(sudregResults, id: \.mbs) { subject in
                            ClientRow(
                                name: subject.naziv,
                                subtitle: [subject.adresa, subject.mjesto].filter { !$0.isEmpty }.joined(separator: ", "),
                                oib: subject.oib,
                                source: .sudreg,
                                action: {
                                    saveAndSelectSudregClient(subject)
                                }
                            )
                        }
                    }
                    
                    if isSearchingSudreg {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Pretraga sudskog registra...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                    }
                    
                    // Error state
                    if let error = sudregError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                    }
                    
                    // Empty state
                    if filteredLocal.isEmpty && builtinResults.isEmpty && sudregResults.isEmpty && !isSearchingSudreg {
                        VStack(spacing: 12) {
                            Image(systemName: searchText.isEmpty ? "person.crop.circle.badge.questionmark" : "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundStyle(.quaternary)
                            
                            if searchText.isEmpty {
                                Text("Unesite naziv tvrtke")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                Text("Počnite tipkati naziv tvrtke — automatski pretražujemo sudski registar i popunjavamo OIB, adresu i ostale podatke.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 300)
                            } else {
                                Text("Nema rezultata")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                Text("Nismo pronašli tvrtku \"\(searchText)\" — pokušajte s drugačijim nazivom ili dodajte klijenta ručno.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 300)
                            }
                        }
                        .padding(40)
                    }
                }
            }
            
            Divider()
            
            // Bottom: Add manually button + search online button
            HStack {
                Button {
                    showAddClientForm = true
                } label: {
                    Label("Dodaj ručno", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if sudregConfigured {
                    Button("Traži online") {
                        triggerSudregSearch()
                    }
                    .buttonStyle(.bordered)
                    .disabled(searchText.count < 3 || isSearchingSudreg)
                }
            }
            .padding(16)
        }
        .onAppear {
            sudregConfigured = sudregService.isConfigured
        }
        .onChange(of: searchText) { _, newValue in
            debouncedSearch(query: newValue)
        }
        .sheet(isPresented: $showAddClientForm) {
            ManualClientForm(clientData: $newClient) { client in
                modelContext.insert(client)
                try? modelContext.save()
                selectedClient = client
                dismiss()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    /// Debounced search — waits 500ms after typing stops, then searches Sudreg.
    /// Built-in institutions are searched immediately (no network call).
    private func debouncedSearch(query: String) {
        // Cancel any pending search
        searchTask?.cancel()
        
        // Search built-in institutions immediately (local, no debounce needed)
        if query.count >= 2 {
            builtinResults = frequentClientsService.search(query: query)
        } else {
            builtinResults = []
        }
        
        // Clear Sudreg results if query is too short
        guard query.count >= 3 else {
            sudregResults = []
            sudregError = nil
            return
        }
        
        // Debounce: wait 500ms before searching Sudreg (network call)
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            guard !Task.isCancelled else { return }
            
            await performSudregSearch(query: query)
        }
    }
    
    /// Explicitly trigger an immediate Sudreg search
    private func triggerSudregSearch() {
        searchTask?.cancel()
        guard searchText.count >= 3 else { return }
        
        Task {
            await performSudregSearch(query: searchText)
        }
    }
    
    /// Perform the actual Sudreg API search
    private func performSudregSearch(query: String) async {
        guard sudregConfigured else { return }
        
        await MainActor.run {
            isSearchingSudreg = true
            sudregError = nil
        }
        
        let results = await sudregService.searchSubjects(query: query)
        
        await MainActor.run {
            sudregResults = results
            isSearchingSudreg = false
            
            if results.isEmpty && !query.isEmpty {
                // Don't show error, just empty state — could be a valid "no results" case
            }
        }
    }
    
    private func saveAndSelectSudregClient(_ subject: SudregSubject) {
        // Check if client already exists by OIB
        if let existing = localClients.first(where: { $0.oib == subject.oib && !subject.oib.isEmpty }) {
            selectedClient = existing
            dismiss()
            return
        }
        
        // Check by MBS as fallback
        if let existing = localClients.first(where: { $0.mbs == subject.mbs && !subject.mbs.isEmpty }) {
            // Update existing client with fresh Sudreg data
            existing.oib = subject.oib.isEmpty ? existing.oib : subject.oib
            existing.address = subject.adresa.isEmpty ? existing.address : subject.adresa
            existing.city = subject.mjesto.isEmpty ? existing.city : subject.mjesto
            existing.zipCode = subject.postanskiBroj.isEmpty ? existing.zipCode : subject.postanskiBroj
            try? modelContext.save()
            selectedClient = existing
            dismiss()
            return
        }
        
        let client = Client(
            name: subject.naziv,
            oib: subject.oib,
            mbs: subject.mbs,
            address: subject.adresa,
            city: subject.mjesto,
            zipCode: subject.postanskiBroj
        )
        modelContext.insert(client)
        try? modelContext.save()
        selectedClient = client
        dismiss()
    }
    
    private func saveAndSelectBuiltinClient(_ frequent: FrequentClient) {
        // Check if client already exists by OIB
        if let existing = localClients.first(where: { $0.oib == frequent.oib && !frequent.oib.isEmpty }) {
            selectedClient = existing
            dismiss()
            return
        }
        
        let client = Client(
            name: frequent.name,
            oib: frequent.oib,
            address: frequent.address,
            city: frequent.city,
            zipCode: frequent.zipCode
        )
        modelContext.insert(client)
        try? modelContext.save()
        selectedClient = client
        dismiss()
    }
}

// MARK: - Client Row

enum ClientSource {
    case local, sudreg, builtin
}

struct ClientRow: View {
    let name: String
    let subtitle: String
    let oib: String
    let source: ClientSource
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.brandAccent) private var brandAccent
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(sourceColor.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: sourceIcon)
                        .font(.system(size: 13))
                        .foregroundStyle(sourceColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if !oib.isEmpty {
                    Text("OIB: \(oib)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                
                if source == .sudreg || source == .builtin {
                    Text(source == .builtin ? "Javna inst." : "Autofill")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(sourceColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sourceColor.opacity(0.1), in: Capsule())
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
            
            Divider().padding(.leading, 66)
        }
    }
    
    private var sourceColor: Color {
        switch source {
        case .local: return brandAccent
        case .sudreg: return .blue
        case .builtin: return .teal
        }
    }
    
    private var sourceIcon: String {
        switch source {
        case .local: return "person.fill"
        case .sudreg: return "building.columns.fill"
        case .builtin: return "building.2.fill"
        }
    }
}

// MARK: - Manual Client Form

struct NewClientData {
    var name = ""
    var oib = ""
    var mbs = ""
    var address = ""
    var city = ""
    var zipCode = ""
    var contactPerson = ""
    var email = ""
    var phone = ""
}

struct ManualClientForm: View {
    @Binding var clientData: NewClientData
    let onSave: (Client) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.brandAccent) private var brandAccent
    
    // Sudreg autofill state
    @State private var sudregResults: [SudregSubject] = []
    @State private var builtinResults: [FrequentClient] = []
    @State private var isSearchingSudreg = false
    @State private var showSuggestions = false
    @State private var searchTask: Task<Void, Never>?
    @State private var didAutofill = false
    
    private let sudregService = SudregService()
    private let frequentClientsService = FrequentClientsService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Novi klijent")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - Name field with Sudreg autofill
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OSNOVNI PODACI")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        // Name field + search indicator
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            
                            TextField("Naziv tvrtke *", text: $clientData.name)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                            
                            if isSearchingSudreg {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 16, height: 16)
                            }
                            
                            if didAutofill {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                    Text("Sudreg")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.1), in: Capsule())
                            }
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(didAutofill ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        
                        // Sudreg suggestion help text
                        if sudregService.isConfigured && !didAutofill && clientData.name.count < 3 {
                            HStack(spacing: 4) {
                                Image(systemName: "building.columns")
                                    .font(.system(size: 9))
                                Text("Upišite 3+ znaka za automatsku pretragu sudskog registra")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(.tertiary)
                        }
                        
                        if !sudregService.isConfigured {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.orange)
                                Text("Sudreg API nije konfiguriran — Postavke → Sudreg API")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // MARK: Built-in public institution suggestions
                        if showSuggestions && !builtinResults.isEmpty {
                            VStack(spacing: 0) {
                                HStack(spacing: 4) {
                                    Image(systemName: "building.2.fill")
                                        .font(.system(size: 9))
                                    Text("JAVNE INSTITUCIJE — ODABERI ZA AUTOFILL")
                                        .font(.system(size: 9, weight: .semibold))
                                    Spacer()
                                    Text("\(builtinResults.count) rezultata")
                                        .font(.system(size: 9))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.teal.opacity(0.05))
                                
                                ForEach(builtinResults) { client in
                                    Button {
                                        applyBuiltinAutofill(client)
                                    } label: {
                                        HStack(spacing: 10) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.teal.opacity(0.12))
                                                    .frame(width: 28, height: 28)
                                                Image(systemName: "building.2.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.teal)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(client.name)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .lineLimit(1)
                                                    .foregroundStyle(.primary)
                                                
                                                HStack(spacing: 8) {
                                                    Text("OIB: \(client.oib)")
                                                        .font(.system(size: 10, design: .monospaced))
                                                    Text(client.city)
                                                        .font(.system(size: 10))
                                                }
                                                .foregroundStyle(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Text("Popuni")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.teal)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(.teal.opacity(0.1), in: Capsule())
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if client.oib != builtinResults.last?.oib {
                                        Divider().padding(.leading, 48)
                                    }
                                }
                            }
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.teal.opacity(0.2), lineWidth: 1)
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // MARK: Sudreg suggestions dropdown
                        if showSuggestions && !sudregResults.isEmpty {
                            VStack(spacing: 0) {
                                HStack(spacing: 4) {
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 9))
                                    Text("SUDSKI REGISTAR — ODABERI ZA AUTOFILL")
                                        .font(.system(size: 9, weight: .semibold))
                                    Spacer()
                                    Text("\(sudregResults.count) rezultata")
                                        .font(.system(size: 9))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.05))
                                
                                ForEach(sudregResults, id: \.mbs) { subject in
                                    Button {
                                        applySudregAutofill(subject)
                                    } label: {
                                        HStack(spacing: 10) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.blue.opacity(0.12))
                                                    .frame(width: 28, height: 28)
                                                Image(systemName: "building.columns.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.blue)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(subject.naziv)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .lineLimit(1)
                                                    .foregroundStyle(.primary)
                                                
                                                HStack(spacing: 8) {
                                                    if !subject.oib.isEmpty {
                                                        Text("OIB: \(subject.oib)")
                                                            .font(.system(size: 10, design: .monospaced))
                                                    }
                                                    if !subject.mjesto.isEmpty {
                                                        Text(subject.mjesto)
                                                            .font(.system(size: 10))
                                                    }
                                                }
                                                .foregroundStyle(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Text("Popuni")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.blue)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(.blue.opacity(0.1), in: Capsule())
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if subject.mbs != sudregResults.last?.mbs {
                                        Divider().padding(.leading, 48)
                                    }
                                }
                            }
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // OIB field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("OIB")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            TextField("OIB", text: $clientData.oib)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                        }
                        .padding(.top, 4)
                        
                        // Contact person
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Kontakt osoba")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            TextField("Kontakt osoba", text: $clientData.contactPerson)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                        }
                    }
                    
                    // MARK: - Address section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ADRESA")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ulica i broj")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            TextField("Ulica i broj", text: $clientData.address)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                        }
                        
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Poštanski broj")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                TextField("Poštanski broj", text: $clientData.zipCode)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13))
                                    .frame(width: 100)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Grad")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                TextField("Grad", text: $clientData.city)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13))
                            }
                        }
                    }
                    
                    // MARK: - Contact section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("KONTAKT")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            TextField("Email", text: $clientData.email)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Telefon")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            TextField("Telefon", text: $clientData.phone)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                        }
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Odustani") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Spremi") {
                    let client = Client(
                        name: clientData.name,
                        oib: clientData.oib,
                        mbs: clientData.mbs,
                        address: clientData.address,
                        city: clientData.city,
                        zipCode: clientData.zipCode,
                        contactPerson: clientData.contactPerson,
                        email: clientData.email,
                        phone: clientData.phone
                    )
                    onSave(client)
                }
                .buttonStyle(.borderedProminent)
                .tint(brandAccent)
                .disabled(clientData.name.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 500, height: 580)
        .onChange(of: clientData.name) { _, newValue in
            debouncedSudregSearch(query: newValue)
        }
    }
    
    // MARK: - Sudreg Autofill
    
    private func debouncedSudregSearch(query: String) {
        // Cancel pending search
        searchTask?.cancel()
        
        // If user manually edited name after autofill, reset autofill state
        if didAutofill {
            didAutofill = false
        }
        
        // Search built-in institutions immediately (local, no debounce needed)
        if query.count >= 2 {
            builtinResults = frequentClientsService.search(query: query)
            if !builtinResults.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSuggestions = true
                }
            }
        } else {
            builtinResults = []
        }
        
        guard sudregService.isConfigured, query.count >= 3 else {
            withAnimation(.easeInOut(duration: 0.2)) {
                sudregResults = []
                if builtinResults.isEmpty {
                    showSuggestions = false
                }
            }
            return
        }
        
        searchTask = Task {
            // Debounce 500ms
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isSearchingSudreg = true
            }
            
            let results = await sudregService.searchSubjects(query: query)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isSearchingSudreg = false
                sudregResults = results
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSuggestions = !results.isEmpty || !builtinResults.isEmpty
                }
            }
        }
    }
    
    private func applySudregAutofill(_ subject: SudregSubject) {
        withAnimation(.easeInOut(duration: 0.2)) {
            clientData.name = subject.naziv
            clientData.oib = subject.oib
            clientData.mbs = subject.mbs
            clientData.address = subject.adresa
            clientData.city = subject.mjesto
            clientData.zipCode = subject.postanskiBroj
            
            sudregResults = []
            builtinResults = []
            showSuggestions = false
            didAutofill = true
        }
    }
    
    private func applyBuiltinAutofill(_ client: FrequentClient) {
        withAnimation(.easeInOut(duration: 0.2)) {
            clientData.name = client.name
            clientData.oib = client.oib
            clientData.mbs = ""
            clientData.address = client.address
            clientData.city = client.city
            clientData.zipCode = client.zipCode
            
            sudregResults = []
            builtinResults = []
            showSuggestions = false
            didAutofill = true
        }
    }
}
