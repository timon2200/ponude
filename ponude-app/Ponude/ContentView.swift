import SwiftUI
import SwiftData

/// The root navigation view with a sidebar and detail pane.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessProfile.createdAt) private var profiles: [BusinessProfile]
    
    @State private var selectedNav: NavItem = .dashboard
    @State private var selectedProfile: BusinessProfile?
    @State private var editingPonuda: Ponuda?
    @State private var editingRacun: Racun?
    @State private var sourcePonuda: Ponuda?
    @State private var showProfileSwitcher = false
    @State private var profileToDelete: BusinessProfile?
    
    enum NavItem: Hashable {
        case dashboard
        case clients
        case newQuote
        case racuni
        case newRacun
        case addCompany
    }
    
    private var accentColor: Color {
        Color(hex: selectedProfile?.brandColorHex ?? "#C5A55A")
    }
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
                .toolbar(.hidden)
                .navigationTitle("")
        }
        .environment(\.brandAccent, accentColor)
        .frame(minWidth: 1100, minHeight: 700)
        .onAppear(perform: initializeProfiles)
        .onReceive(NotificationCenter.default.publisher(for: .createNewQuote)) { _ in
            editingPonuda = nil
            selectedNav = .newQuote
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedNav) {
                // Clickable company switcher
                if profiles.count > 0 {
                    Section {
                        Button {
                            showProfileSwitcher.toggle()
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: selectedProfile?.brandColorHex ?? "#C5A55A").gradient)
                                        .frame(width: 36, height: 36)
                                    Text(String((selectedProfile?.shortName ?? "?").prefix(1)))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedProfile?.shortName ?? "Odaberi tvrtku")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(selectedProfile?.taxStatus.rawValue ?? "")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showProfileSwitcher, arrowEdge: .trailing) {
                            profileSwitcherPopover
                        }
                    } header: {
                        Text("Tvrtka")
                    }
                }
                
                Section {
                    Label("Ponude", systemImage: "doc.text.fill")
                        .tag(NavItem.dashboard)
                    
                    Label("Računi", systemImage: "banknote.fill")
                        .tag(NavItem.racuni)
                    
                    Label("Klijenti", systemImage: "person.2.fill")
                        .tag(NavItem.clients)
                } header: {
                    Text("Izbornik")
                }
            }
            .listStyle(.sidebar)
            
            // New quote button pinned at bottom
            VStack {
                Divider()
                Button {
                    editingPonuda = nil
                    selectedNav = .newQuote
                } label: {
                    Label("Nova ponuda", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedNav {
        case .dashboard:
            DashboardView(
                selectedProfile: selectedProfile,
                onNewQuote: {
                    editingPonuda = nil
                    selectedNav = .newQuote
                },
                onEditQuote: { ponuda in
                    editingPonuda = ponuda
                    selectedNav = .newQuote
                },
                onCreateInvoice: { ponuda in
                    sourcePonuda = ponuda
                    editingRacun = nil
                    selectedNav = .newRacun
                }
            )
            
        case .clients:
            ClientListView()
            
        case .newQuote:
            if let profile = selectedProfile {
                QuoteBuilderView(
                    businessProfile: profile,
                    existingPonuda: editingPonuda,
                    onDismiss: {
                        editingPonuda = nil
                        selectedNav = .dashboard
                    }
                )
                .id(editingPonuda?.persistentModelID ?? profile.persistentModelID)
            } else {
                noProfileView
            }
            
        case .racuni:
            InvoiceDashboardView(
                selectedProfile: selectedProfile,
                onNewInvoice: {
                    editingRacun = nil
                    sourcePonuda = nil
                    selectedNav = .newRacun
                },
                onEditInvoice: { racun in
                    editingRacun = racun
                    sourcePonuda = nil
                    selectedNav = .newRacun
                }
            )
            
        case .newRacun:
            if let profile = selectedProfile {
                InvoiceBuilderView(
                    businessProfile: profile,
                    existingRacun: editingRacun,
                    sourcePonuda: sourcePonuda,
                    onDismiss: {
                        editingRacun = nil
                        sourcePonuda = nil
                        selectedNav = .racuni
                    }
                )
                .id(editingRacun?.persistentModelID ?? sourcePonuda?.persistentModelID ?? profile.persistentModelID)
            } else {
                noProfileView
            }
            
        case .addCompany:
            AddCompanyWizardView { newProfile in
                selectedProfile = newProfile
                selectedNav = .dashboard
            }
        }
    }
    
    private var noProfileView: some View {
        ContentUnavailableView(
            "Nema aktivne tvrtke",
            systemImage: "building.2",
            description: Text("Dodajte poslovni profil u Postavkama kako biste mogli kreirati dokumente.")
        )
    }
    
    // MARK: - Profile Switcher Popover
    
    private var profileSwitcherPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Odaberi tvrtku")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            Divider()
            
            ForEach(profiles) { profile in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProfile = profile
                    }
                    showProfileSwitcher = false
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: profile.brandColorHex).gradient)
                                .frame(width: 28, height: 28)
                            Text(String(profile.shortName.prefix(1)))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(profile.shortName)
                                .font(.system(size: 13, weight: .medium))
                            Text(profile.taxStatus.rawValue)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedProfile?.id == profile.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(
                        selectedProfile?.id == profile.id
                            ? Color(hex: profile.brandColorHex).opacity(0.08)
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        profileToDelete = profile
                    } label: {
                        Label("Obriši tvrtku", systemImage: "trash")
                    }
                }
                
                if profile.id != profiles.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
            
            Divider()
                .padding(.top, 4)
            
            // Add new company button
            Button {
                showProfileSwitcher = false
                selectedNav = .addCompany
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Dodaj tvrtku")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 240)
        .padding(.bottom, 8)
        .alert(
            "Obriši tvrtku?",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            )
        ) {
            Button("Odustani", role: .cancel) {
                profileToDelete = nil
            }
            Button("Obriši", role: .destructive) {
                if let profile = profileToDelete {
                    deleteProfile(profile)
                }
                profileToDelete = nil
            }
        } message: {
            if let profile = profileToDelete {
                Text("Jeste li sigurni da želite obrisati \"\(profile.shortName)\"? Sve povezane ponude će također biti obrisane.")
            }
        }
    }
    
    // MARK: - Actions
    
    private func deleteProfile(_ profile: BusinessProfile) {
        let wasSelected = selectedProfile?.id == profile.id
        modelContext.delete(profile)
        try? modelContext.save()
        
        if wasSelected {
            selectedProfile = profiles.first(where: { $0.id != profile.id }) ?? profiles.first
        }
    }
    
    // MARK: - Initialization
    
    private func initializeProfiles() {
        // Canonical data for each business profile
        struct ProfileData {
            let name: String
            let shortName: String
            let ownerName: String
            let oib: String
            let iban: String
            let address: String
            let city: String
            let zipCode: String
            let phone: String
            let email: String
            let website: String
            let vatExemptNote: String
            let brandColorHex: String
            let isDefault: Bool
        }
        
        let canonical: [ProfileData] = [
            ProfileData(
                name: "Lotus RC, vl. Timon Terzić",
                shortName: "Lotus RC",
                ownerName: "Timon Terzić",
                oib: "58278708852",
                iban: "HR9824020061140483524",
                address: "S. Vraza 10",
                city: "Varaždin",
                zipCode: "42000",
                phone: "",
                email: "",
                website: "",
                vatExemptNote: "Oslobođeno PDV-a temeljem članka 90. st. 2 Zakona o PDV-u.",
                brandColorHex: "#C5A55A",
                isDefault: true
            ),
            ProfileData(
                name: "STUDIO VARAŽDIN, obrt za usluge, vl. Jasenka Martinčević",
                shortName: "Studio Varaždin",
                ownerName: "Jasenka Martinčević",
                oib: "63287352089",
                iban: "HR9223600001103240533",
                address: "S. Vraza 10",
                city: "Varaždin",
                zipCode: "42000",
                phone: "",
                email: "",
                website: "",
                vatExemptNote: "Oslobođeno PDV-a temeljem članka 90. st. 2 Zakona o PDV-u.",
                brandColorHex: "#4F46E5",
                isDefault: false
            ),
            ProfileData(
                name: "Lovements, vl. Bojan Horvat",
                shortName: "Lovements",
                ownerName: "Bojan Horvat",
                oib: "71365460157",
                iban: "HR0823600003117106090",
                address: "Drenovec 127",
                city: "Varaždinske Toplice",
                zipCode: "42223",
                phone: "",
                email: "",
                website: "",
                vatExemptNote: "Oslobođeno PDV-a temeljem članka 90. st. 2 Zakona o PDV-u.",
                brandColorHex: "#E54F71",
                isDefault: false
            ),
            ProfileData(
                name: "DOMY MEDIA, obrt za videoprodukciju i usluge, vl. Dorian Domiter",
                shortName: "Domy Media",
                ownerName: "Dorian Domiter",
                oib: "02942763384",
                iban: "",
                address: "Gajeva ulica 2",
                city: "Trnovec",
                zipCode: "42202",
                phone: "",
                email: "",
                website: "",
                vatExemptNote: "Oslobođeno PDV-a temeljem članka 90. st. 2 Zakona o PDV-u.",
                brandColorHex: "#7B2FF7",
                isDefault: false
            ),
        ]
        
        var didChange = false
        
        for data in canonical {
            if let existing = profiles.first(where: { $0.shortName == data.shortName }) {
                // Update existing profile with correct canonical data
                var changed = false
                if existing.name != data.name { existing.name = data.name; changed = true }
                if existing.ownerName != data.ownerName { existing.ownerName = data.ownerName; changed = true }
                if existing.oib.isEmpty && !data.oib.isEmpty { existing.oib = data.oib; changed = true }
                if existing.iban.isEmpty && !data.iban.isEmpty { existing.iban = data.iban; changed = true }
                if existing.address.isEmpty && !data.address.isEmpty { existing.address = data.address; changed = true }
                if existing.city.isEmpty && !data.city.isEmpty { existing.city = data.city; changed = true }
                if existing.zipCode.isEmpty && !data.zipCode.isEmpty { existing.zipCode = data.zipCode; changed = true }
                if existing.vatExemptNote.isEmpty || existing.vatExemptNote.contains("čl. 90. st. 1") {
                    if !data.vatExemptNote.isEmpty {
                        existing.vatExemptNote = data.vatExemptNote
                        changed = true
                    }
                }
                if changed { didChange = true }
            } else {
                // Create new profile
                let profile = BusinessProfile(
                    name: data.name,
                    shortName: data.shortName,
                    ownerName: data.ownerName,
                    oib: data.oib,
                    iban: data.iban,
                    address: data.address,
                    city: data.city,
                    zipCode: data.zipCode,
                    phone: data.phone,
                    email: data.email,
                    website: data.website,
                    vatExemptNote: data.vatExemptNote,
                    brandColorHex: data.brandColorHex,
                    isDefault: data.isDefault
                )
                modelContext.insert(profile)
                didChange = true
            }
        }
        
        if didChange {
            try? modelContext.save()
        }
        
        selectedProfile = profiles.first(where: { $0.isDefault }) ?? profiles.first
    }
}
