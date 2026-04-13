import SwiftUI
import SwiftData

/// App Settings view shown via the macOS Settings menu (⌘,)
struct SettingsView: View {
    @State private var selectedTab = "profiles"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BusinessProfilesTab()
                .tabItem {
                    Label("Tvrtke", systemImage: "building.2.fill")
                }
                .tag("profiles")
            
            SudregSettingsTab()
                .tabItem {
                    Label("Sudreg API", systemImage: "network")
                }
                .tag("sudreg")
            
            DefaultsTab()
                .tabItem {
                    Label("Zadano", systemImage: "gearshape.fill")
                }
                .tag("defaults")
        }
        .frame(width: 550, height: 450)
    }
}

// MARK: - Business Profiles Tab

struct BusinessProfilesTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessProfile.createdAt) private var profiles: [BusinessProfile]
    
    @State private var selectedProfile: BusinessProfile?
    @State private var showEditor = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Poslovni profili")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button {
                    selectedProfile = nil
                    showEditor = true
                } label: {
                    Label("Dodaj", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.gold)
                .controlSize(.small)
            }
            .padding(20)
            
            Divider()
            
            List(profiles, selection: $selectedProfile) { profile in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: profile.brandColorHex).gradient)
                            .frame(width: 30, height: 30)
                        Text(String(profile.shortName.prefix(1)))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(profile.shortName)
                                .font(.system(size: 13, weight: .semibold))
                            if profile.isDefault {
                                Text("Zadano")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(DesignTokens.gold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(DesignTokens.gold.opacity(0.12), in: Capsule())
                            }
                        }
                        Text(profile.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button("Uredi") {
                            selectedProfile = profile
                            showEditor = true
                        }
                        .controlSize(.small)
                        
                        Button(role: .destructive) {
                            selectedProfile = profile
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .alert("Obriši profil?", isPresented: $showDeleteAlert) {
            Button("Obriši", role: .destructive) {
                if let profile = selectedProfile {
                    modelContext.delete(profile)
                    try? modelContext.save()
                }
            }
            Button("Odustani", role: .cancel) { }
        }
        .sheet(isPresented: $showEditor) {
            BusinessProfileEditor(existingProfile: selectedProfile)
        }
    }
}

// MARK: - Sudreg API Settings

struct SudregSettingsTab: View {
    @AppStorage("sudregClientId") private var clientId = ""
    @AppStorage("sudregClientSecret") private var clientSecret = ""
    @State private var testResult: String?
    @State private var isTesting = false
    
    var body: some View {
        Form {
            Section {
                Text("Za pretragu klijenata putem Sudskog registra potrebne su pristupne podatke. Registrirajte se na sudreg-data.gov.hr.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Section("Pristupni podaci") {
                TextField("Client ID", text: $clientId)
                SecureField("Client Secret", text: $clientSecret)
            }
            
            Section {
                HStack {
                    Button("Testiraj vezu") {
                        testConnection()
                    }
                    .disabled(clientId.isEmpty || clientSecret.isEmpty || isTesting)
                    
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    
                    if let result = testResult {
                        Text(result)
                            .font(.system(size: 12))
                            .foregroundStyle(result.contains("✓") ? .green : .red)
                    }
                }
                
                Link("Registriraj se na sudreg-data.gov.hr",
                     destination: URL(string: "https://sudreg-data.gov.hr")!)
                    .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        
        Task {
            let service = SudregService()
            let success = await service.testConnection()
            await MainActor.run {
                testResult = success ? "✓ Veza uspješna!" : "✗ Greška pri povezivanju"
                isTesting = false
            }
        }
    }
}

// MARK: - Defaults Tab

struct DefaultsTab: View {
    @AppStorage("defaultMjesto") private var defaultMjesto = ""
    @AppStorage("defaultRokValjanosti") private var defaultRok = 30
    
    var body: some View {
        Form {
            Section("Zadane vrijednosti za nove ponude") {
                TextField("Zadano mjesto", text: $defaultMjesto)
                Stepper("Rok valjanosti: \(defaultRok) dana", value: $defaultRok, in: 1...365)
            }
            
            Section("Informacije") {
                HStack {
                    Text("Verzija aplikacije")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
