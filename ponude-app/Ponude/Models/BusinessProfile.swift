import Foundation
import SwiftData

/// Tax classification for Croatian businesses
enum TaxStatus: String, Codable, CaseIterable {
    case pausalnObrt = "Paušalni obrtnik"
    case uSustavuPDV = "U sustavu PDV-a"
    case slobodnoZanimanje = "Slobodno zanimanje"
}

/// A business entity that can issue quotes.
/// Each profile stores branding, contact info, and tax details.
@Model
final class BusinessProfile {
    var name: String             // Full trade name: "Lotus RC, vl. Timon Terzić"
    var shortName: String        // Brand name: "Lotus RC"
    var ownerName: String        // Owner: "Timon Terzić"
    var oib: String              // Croatian tax ID
    var iban: String             // Bank account
    var address: String          // Street address
    var city: String             // City name
    var zipCode: String          // Postal code
    var phone: String
    var email: String
    var website: String
    var taxStatusRaw: String     // Stored as raw string for SwiftData
    var vatExemptNote: String    // Legal note for VAT exemption
    var brandColorHex: String    // Hex color for template accent
    @Attribute(.externalStorage)
    var logoData: Data?          // Optional brand logo
    var isDefault: Bool
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Ponuda.businessProfile)
    var ponude: [Ponuda] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Racun.businessProfile)
    var racuni: [Racun] = []
    
    var taxStatus: TaxStatus {
        get { TaxStatus(rawValue: taxStatusRaw) ?? .pausalnObrt }
        set { taxStatusRaw = newValue.rawValue }
    }
    
    var fullAddress: String {
        if zipCode.isEmpty {
            return "\(address), \(city)"
        }
        return "\(address), \(zipCode) \(city)"
    }
    
    init(
        name: String,
        shortName: String,
        ownerName: String,
        oib: String = "",
        iban: String = "",
        address: String = "",
        city: String = "",
        zipCode: String = "",
        phone: String = "",
        email: String = "",
        website: String = "",
        taxStatus: TaxStatus = .pausalnObrt,
        vatExemptNote: String = "Oslobođeno PDV-a temeljem čl. 90. st. 1. Zakona o PDV-u.",
        brandColorHex: String = "#C5A55A",
        logoData: Data? = nil,
        isDefault: Bool = false
    ) {
        self.name = name
        self.shortName = shortName
        self.ownerName = ownerName
        self.oib = oib
        self.iban = iban
        self.address = address
        self.city = city
        self.zipCode = zipCode
        self.phone = phone
        self.email = email
        self.website = website
        self.taxStatusRaw = taxStatus.rawValue
        self.vatExemptNote = vatExemptNote
        self.brandColorHex = brandColorHex
        self.logoData = logoData
        self.isDefault = isDefault
        self.createdAt = Date()
    }
}
