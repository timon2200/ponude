import SwiftUI
import SwiftData

/// Form for creating or editing a business profile.
struct BusinessProfileEditor: View {
    let existingProfile: BusinessProfile?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var shortName = ""
    @State private var ownerName = ""
    @State private var oib = ""
    @State private var iban = ""
    @State private var address = ""
    @State private var city = ""
    @State private var zipCode = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var taxStatus: TaxStatus = .pausalnObrt
    @State private var vatExemptNote = "Oslobođeno PDV-a temeljem čl. 90. st. 1. Zakona o PDV-u."
    @State private var brandColorHex = "#C5A55A"
    @State private var isDefault = false
    
    private let colorPresets = [
        "#C5A55A", "#4F46E5", "#0EA5E9", "#10B981",
        "#F59E0B", "#EF4444", "#8B5CF6", "#1A1A1A"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existingProfile != nil ? "Uredi profil" : "Novi poslovni profil")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
            
            Form {
                Section("Tvrtka") {
                    TextField("Puni naziv (npr. Lotus RC, vl. Timon Terzić)", text: $name)
                    TextField("Kratki naziv / brand (npr. Lotus RC)", text: $shortName)
                    TextField("Ime vlasnika", text: $ownerName)
                }
                
                Section("Identifikacija") {
                    TextField("OIB", text: $oib)
                    TextField("IBAN", text: $iban)
                }
                
                Section("Adresa") {
                    TextField("Ulica i broj", text: $address)
                    HStack {
                        TextField("Poštanski broj", text: $zipCode)
                            .frame(width: 100)
                        TextField("Grad", text: $city)
                    }
                }
                
                Section("Kontakt") {
                    TextField("Telefon", text: $phone)
                    TextField("Email", text: $email)
                    TextField("Web stranica", text: $website)
                }
                
                Section("Porezni status") {
                    Picker("Status", selection: $taxStatus) {
                        ForEach(TaxStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    TextField("Napomena o PDV-u", text: $vatExemptNote)
                        .font(.system(size: 11))
                }
                
                Section("Branding") {
                    HStack(spacing: 8) {
                        Text("Boja")
                            .font(.system(size: 12))
                        
                        ForEach(colorPresets, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if brandColorHex == hex {
                                        Circle()
                                            .stroke(.white, lineWidth: 2)
                                            .frame(width: 16, height: 16)
                                    }
                                }
                                .onTapGesture {
                                    brandColorHex = hex
                                }
                        }
                    }
                    
                    Toggle("Zadani profil", isOn: $isDefault)
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            // Actions
            HStack {
                Spacer()
                Button("Odustani") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Spremi") {
                    saveProfile()
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.gold)
                .disabled(name.isEmpty || shortName.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding(16)
        }
        .frame(width: 520, height: 620)
        .onAppear {
            if let p = existingProfile {
                name = p.name
                shortName = p.shortName
                ownerName = p.ownerName
                oib = p.oib
                iban = p.iban
                address = p.address
                city = p.city
                zipCode = p.zipCode
                phone = p.phone
                email = p.email
                website = p.website
                taxStatus = p.taxStatus
                vatExemptNote = p.vatExemptNote
                brandColorHex = p.brandColorHex
                isDefault = p.isDefault
            }
        }
    }
    
    private func saveProfile() {
        if let existing = existingProfile {
            existing.name = name
            existing.shortName = shortName
            existing.ownerName = ownerName
            existing.oib = oib
            existing.iban = iban
            existing.address = address
            existing.city = city
            existing.zipCode = zipCode
            existing.phone = phone
            existing.email = email
            existing.website = website
            existing.taxStatus = taxStatus
            existing.vatExemptNote = vatExemptNote
            existing.brandColorHex = brandColorHex
            existing.isDefault = isDefault
        } else {
            let profile = BusinessProfile(
                name: name,
                shortName: shortName,
                ownerName: ownerName,
                oib: oib,
                iban: iban,
                address: address,
                city: city,
                zipCode: zipCode,
                phone: phone,
                email: email,
                website: website,
                taxStatus: taxStatus,
                vatExemptNote: vatExemptNote,
                brandColorHex: brandColorHex,
                isDefault: isDefault
            )
            modelContext.insert(profile)
        }
        
        try? modelContext.save()
        dismiss()
    }
}
