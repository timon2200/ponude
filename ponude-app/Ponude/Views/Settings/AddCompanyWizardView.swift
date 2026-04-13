import SwiftUI
import SwiftData

/// A fun, gamified wizard for adding a new business profile (tvrtka).
/// Each step features animated emojis, smooth transitions, and friendly copy.
struct AddCompanyWizardView: View {
    @Environment(\.modelContext) private var modelContext
    
    /// Callback when a new profile is created
    var onProfileCreated: ((BusinessProfile) -> Void)?
    
    // MARK: - Wizard State
    
    enum WizardStep: Int, CaseIterable {
        case searchCompany = 0
        case companyFound
        case confirmName
        case address
        case iban
        case brandAndFinish
        case celebration
        
        var emoji: String {
            switch self {
            case .searchCompany: return "🔍"
            case .companyFound: return "✅"
            case .confirmName: return "🏢"
            case .address: return "📍"
            case .iban: return "💳"
            case .brandAndFinish: return "🎨"
            case .celebration: return "🎉"
            }
        }
        
        var title: String {
            switch self {
            case .searchCompany: return "Pronađi svoju tvrtku"
            case .companyFound: return "Tvrtka pronađena!"
            case .confirmName: return "Kako se zoveš?"
            case .address: return "Gdje se nalaziš?"
            case .iban: return "Bankovni račun"
            case .brandAndFinish: return "Tvoj stil"
            case .celebration: return "Sve je spremno!"
            }
        }
        
        var subtitle: String {
            switch self {
            case .searchCompany: return "Upiši naziv tvrtke ili OIB"
            case .companyFound: return "Pronašli smo tvoju tvrtku u registru!"
            case .confirmName: return "Potvrdi ili promijeni naziv tvrtke"
            case .address: return "Potvrdi adresu sjedišta"
            case .iban: return "Dodaj IBAN za primanje uplata"
            case .brandAndFinish: return "Odaberi boju brenda i porezni status"
            case .celebration: return "Tvrtka je dodana, možeš početi kreirati ponude! 🚀"
            }
        }
    }
    
    @State private var currentStep: WizardStep = .searchCompany
    @State private var animateEmoji = false
    @State private var pulseEmoji = false
    @State private var slideDirection: Edge = .trailing
    
    // Search fields
    @State private var searchQuery = ""
    @State private var searchResults: [SudregSubject] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var manualMode = false
    
    @State private var companyName = ""
    @State private var shortName = ""
    @State private var ownerName = ""
    @State private var oib = ""
    @State private var streetAddress = ""
    @State private var city = ""
    @State private var zipCode = ""
    @State private var ibanInput = ""
    @State private var selectedTaxStatus: TaxStatus = .pausalnObrt
    @State private var selectedColorHex = "#8B5CF6" // Purple default
    
    private let sudregService = SudregService()
    
    // Brand color options — vibrant, curated palette
    private let colorOptions: [(name: String, hex: String)] = [
        ("Ljubičasta", "#8B5CF6"),
        ("Plava", "#3B82F6"),
        ("Zelena", "#10B981"),
        ("Crvena", "#EF4444"),
        ("Narančasta", "#F59E0B"),
        ("Roza", "#EC4899"),
        ("Tirkizna", "#14B8A6"),
        ("Indigo", "#6366F1"),
        ("Zlato", "#C5A55A"),
        ("Cijan", "#06B6D4"),
    ]
    
    // Check if query looks like an OIB (11 digits)
    private var isOIBQuery: Bool {
        let pattern = "^\\d{11}$"
        return searchQuery.range(of: pattern, options: .regularExpression) != nil
    }
    
    // Minimum characters for name search
    private var canSearch: Bool {
        searchQuery.count >= 3 || isOIBQuery
    }
    
    private var totalSteps: Int { WizardStep.allCases.count - 1 } // exclude celebration from count
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            if currentStep != .celebration {
                progressDots
                    .padding(.top, 20)
                    .padding(.bottom, 8)
            }
            
            // Step content with transitions
            ZStack {
                ForEach(WizardStep.allCases, id: \.rawValue) { step in
                    if step == currentStep {
                        stepContent(for: step)
                            .transition(.asymmetric(
                                insertion: .move(edge: slideDirection).combined(with: .opacity),
                                removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                            ))
                    }
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
            
            Spacer(minLength: 0)
            
            // Navigation buttons
            if currentStep != .celebration {
                navigationButtons
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                
                // Subtle gradient glow from the selected brand color
                RadialGradient(
                    colors: [
                        Color(hex: selectedColorHex).opacity(0.06),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
            }
        )
    }
    
    // MARK: - Progress Dots
    
    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep.rawValue
                          ? Color(hex: selectedColorHex)
                          : Color.secondary.opacity(0.3))
                    .frame(width: index == currentStep.rawValue ? 10 : 6,
                           height: index == currentStep.rawValue ? 10 : 6)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private func stepContent(for step: WizardStep) -> some View {
        VStack(spacing: 0) {
            // Animated emoji
            Text(step.emoji)
                .font(.system(size: 72))
                .scaleEffect(animateEmoji ? 1.0 : 0.1)
                .rotationEffect(.degrees(animateEmoji ? 0 : -180))
                .padding(.top, 32)
                .onAppear {
                    animateEmoji = false
                    pulseEmoji = false
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                        animateEmoji = true
                    }
                    // Start pulse after initial animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            pulseEmoji = true
                        }
                    }
                }
                .scaleEffect(pulseEmoji ? 1.08 : 1.0)
            
            // Title
            Text(step.title)
                .font(.system(size: 22, weight: .bold))
                .padding(.top, 16)
            
            // Subtitle
            Text(step.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 4)
            
            // Step-specific form content
            stepFormContent(for: step)
                .padding(.top, 24)
                .padding(.horizontal, 32)
        }
    }
    
    @ViewBuilder
    private func stepFormContent(for step: WizardStep) -> some View {
        switch step {
        case .searchCompany:
            searchCompanyForm
        case .companyFound:
            companyFoundView
        case .confirmName:
            confirmNameForm
        case .address:
            addressForm
        case .iban:
            ibanForm
        case .brandAndFinish:
            brandForm
        case .celebration:
            celebrationView
        }
    }
    
    // MARK: - Step 1: Search Company
    
    private var searchCompanyForm: some View {
        VStack(spacing: 12) {
            // Search input field
            VStack(alignment: .leading, spacing: 6) {
                Text("Naziv tvrtke ili OIB")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("npr. Studio Varaždin ili 63287352089", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .onChange(of: searchQuery) { _, newValue in
                            debouncedSearch(query: newValue)
                        }
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                            searchError = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    !searchResults.isEmpty ? Color(hex: selectedColorHex).opacity(0.5) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                )
            }
            
            // Search results dropdown
            if !searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(searchResults) { result in
                            Button {
                                selectSearchResult(result)
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(hex: selectedColorHex).opacity(0.15))
                                            .frame(width: 32, height: 32)
                                        Text(String(result.naziv.prefix(1)))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color(hex: selectedColorHex))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.naziv)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                        HStack(spacing: 8) {
                                            if !result.oib.isEmpty {
                                                Text("OIB: \(result.oib)")
                                                    .font(.system(size: 10, design: .monospaced))
                                            }
                                            if !result.mjesto.isEmpty {
                                                Text("📍 \(result.mjesto)")
                                                    .font(.system(size: 10))
                                            }
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if result.id != searchResults.last?.id {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            if let error = searchError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
            
            if searchQuery.count >= 3 && searchResults.isEmpty && !isSearching && searchError == nil {
                Text("Nema rezultata. Potraži drugim nazivom ili dodaj ručno.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            // Manual entry option
            Button {
                manualMode = true
                goToStep(.confirmName)
            } label: {
                Text("Nemam podatke / Dodaj ručno →")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
    
    // MARK: - Step 2: Company Found
    
    private var companyFoundView: some View {
        VStack(spacing: 16) {
            // Show found company info in a nice card
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(companyName.isEmpty ? "—" : companyName)
                        .font(.system(size: 14, weight: .semibold))
                } icon: {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(Color(hex: selectedColorHex))
                }
                
                Label {
                    Text("OIB: \(oib)")
                        .font(.system(size: 13, design: .monospaced))
                } icon: {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                }
                
                if !streetAddress.isEmpty {
                    Label {
                        Text("\(streetAddress), \(zipCode) \(city)")
                            .font(.system(size: 13))
                    } icon: {
                        Image(systemName: "mappin")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: selectedColorHex).opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(hex: selectedColorHex).opacity(0.2), lineWidth: 1)
                    )
            )
            
            Text("Izgleda li ovo ispravno? Možeš promijeniti podatke u sljedećim koracima.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Step 3: Confirm Name
    
    private var confirmNameForm: some View {
        VStack(spacing: 16) {
            wizardField(label: "Puni naziv tvrtke", placeholder: "npr. Lotus RC, vl. Ivan Ivić", text: $companyName)
            wizardField(label: "Kratki naziv (brand)", placeholder: "npr. Lotus RC", text: $shortName)
            wizardField(label: "Ime vlasnika", placeholder: "npr. Ivan Ivić", text: $ownerName)
        }
    }
    
    // MARK: - Step 4: Address
    
    private var addressForm: some View {
        VStack(spacing: 16) {
            wizardField(label: "Ulica i kućni broj", placeholder: "npr. Ulica Grada Vukovara 42", text: $streetAddress)
            
            HStack(spacing: 12) {
                wizardField(label: "Poštanski broj", placeholder: "42000", text: $zipCode)
                    .frame(width: 100)
                wizardField(label: "Grad", placeholder: "npr. Varaždin", text: $city)
            }
        }
    }
    
    // MARK: - Step 5: IBAN
    
    private var ibanForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("IBAN broj")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("HR00 0000 0000 0000 0000 0", text: $ibanInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
            }
            
            Text("IBAN će se prikazivati na tvojim ponudama za uplatu.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Step 6: Brand & Finish
    
    private var brandForm: some View {
        VStack(spacing: 20) {
            // Color picker grid
            VStack(alignment: .leading, spacing: 8) {
                Text("Boja brenda")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(colorOptions, id: \.hex) { option in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedColorHex = option.hex
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: option.hex).gradient)
                                    .frame(width: 40, height: 40)
                                
                                if selectedColorHex == option.hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Tax status picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Porezni status")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $selectedTaxStatus) {
                    ForEach(TaxStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // MARK: - Step 7: Celebration
    
    private var celebrationView: some View {
        VStack(spacing: 24) {
            // Animated confetti-like emoji burst
            HStack(spacing: 16) {
                ForEach(["🎊", "🥳", "🎈", "🎊"], id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 32))
                        .rotationEffect(.degrees(animateEmoji ? 0 : Double.random(in: -30...30)))
                        .scaleEffect(animateEmoji ? 1.0 : 0.3)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.5)
                                .delay(Double.random(in: 0...0.3)),
                            value: animateEmoji
                        )
                }
            }
            
            // Company preview card
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: selectedColorHex).gradient)
                        .frame(width: 40, height: 40)
                    Text(String(shortName.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(shortName.isEmpty ? "Nova tvrtka" : shortName)
                        .font(.system(size: 15, weight: .semibold))
                    Text(selectedTaxStatus.rawValue)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: selectedColorHex).opacity(0.08))
            )
            .padding(.horizontal, 32)
            
            Button {
                createProfileAndDismiss()
            } label: {
                Text("Počni kreirati ponude! 🚀")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: selectedColorHex).gradient)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Reusable Components
    
    private func wizardField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            // Back button (hidden on first step)
            if currentStep.rawValue > 0 {
                Button {
                    goBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Natrag")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Next / Search button
            Button {
                goForward()
            } label: {
                HStack(spacing: 6) {
                    Text(nextButtonTitle)
                        .font(.system(size: 13, weight: .semibold))
                    if currentStep != .brandAndFinish {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(nextButtonEnabled
                              ? Color(hex: selectedColorHex).gradient
                              : Color.secondary.opacity(0.3).gradient)
                )
            }
            .buttonStyle(.plain)
            .disabled(!nextButtonEnabled)
        }
    }
    
    private var nextButtonTitle: String {
        switch currentStep {
        case .searchCompany: return "Dalje"
        case .brandAndFinish: return "Završi! 🎉"
        default: return "Dalje"
        }
    }
    
    private var nextButtonEnabled: Bool {
        switch currentStep {
        case .searchCompany: return false // navigation happens via result selection or manual
        case .companyFound: return true
        case .confirmName: return !shortName.isEmpty && !companyName.isEmpty
        case .address: return !city.isEmpty
        case .iban: return true // IBAN is optional
        case .brandAndFinish: return true
        case .celebration: return true
        }
    }
    
    // MARK: - Navigation Logic
    
    private func goForward() {
        switch currentStep {
        case .searchCompany:
            break // handled by result selection
        case .brandAndFinish:
            goToStep(.celebration)
        default:
            if let next = WizardStep(rawValue: currentStep.rawValue + 1) {
                goToStep(next)
            }
        }
    }
    
    private func goBack() {
        slideDirection = .leading
        if let prev = WizardStep(rawValue: currentStep.rawValue - 1) {
            withAnimation {
                currentStep = prev
            }
        }
        // Reset direction for forward navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            slideDirection = .trailing
        }
    }
    
    private func goToStep(_ step: WizardStep) {
        slideDirection = .trailing
        withAnimation {
            currentStep = step
        }
    }
    
    // MARK: - Search Logic
    
    /// Debounced search — waits 500ms after typing stops before querying Sudreg
    private func debouncedSearch(query: String) {
        searchTask?.cancel()
        searchError = nil
        
        guard query.count >= 3 || (query.allSatisfy(\.isNumber) && query.count == 11) else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            // Debounce delay
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            
            await MainActor.run { isSearching = true }
            
            let results = await sudregService.searchSubjects(query: query)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isSearching = false
                withAnimation(.easeOut(duration: 0.2)) {
                    searchResults = results
                }
                if results.isEmpty && sudregService.isConfigured {
                    // No error text needed — the empty state message handles it
                } else if !sudregService.isConfigured {
                    searchError = "Sudreg API nije konfiguriran."
                }
            }
        }
    }
    
    /// Called when user taps a search result — auto-fills all fields
    private func selectSearchResult(_ result: SudregSubject) {
        companyName = result.naziv
        shortName = extractShortName(from: result.naziv)
        oib = result.oib
        streetAddress = result.adresa
        city = result.mjesto
        zipCode = result.postanskiBroj
        
        goToStep(.companyFound)
    }
    
    /// Extract a short brand name from the full legal name
    /// e.g. "LOTUS RC, vl. Timon Terzić" → "Lotus RC"
    private func extractShortName(from fullName: String) -> String {
        let parts = fullName.components(separatedBy: ",")
        let first = parts.first?.trimmingCharacters(in: .whitespaces) ?? fullName
        return first.capitalized
    }
    
    // MARK: - Create Profile
    
    private func createProfileAndDismiss() {
        let vatNote: String
        switch selectedTaxStatus {
        case .pausalnObrt:
            vatNote = "Oslobođeno PDV-a temeljem članka 90. st. 2 Zakona o PDV-u."
        case .uSustavuPDV:
            vatNote = ""
        case .slobodnoZanimanje:
            vatNote = "Oslobođeno PDV-a temeljem članka 90. st. 2 Zakona o PDV-u."
        }
        
        let profile = BusinessProfile(
            name: companyName,
            shortName: shortName,
            ownerName: ownerName,
            oib: oib,
            iban: ibanInput.replacingOccurrences(of: " ", with: ""),
            address: streetAddress,
            city: city,
            zipCode: zipCode,
            taxStatus: selectedTaxStatus,
            vatExemptNote: vatNote,
            brandColorHex: selectedColorHex,
            isDefault: false
        )
        
        modelContext.insert(profile)
        try? modelContext.save()
        
        onProfileCreated?(profile)
    }
}
