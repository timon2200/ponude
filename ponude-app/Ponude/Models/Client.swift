import Foundation
import SwiftData

/// A client (business entity) that receives quotes.
/// Can be populated from Sudreg API or manual entry.
@Model
final class Client {
    var name: String              // "TURISTIČKA ZAJEDNICA GRADA VARAŽDINA"
    var oib: String               // Croatian tax ID
    var mbs: String               // Matični broj subjekta (Sudreg identifier)
    var address: String           // Street address
    var city: String              // City
    var zipCode: String           // Postal code
    var contactPerson: String     // Contact name
    var email: String
    var phone: String
    var notes: String
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \Ponuda.client)
    var ponude: [Ponuda] = []
    
    var fullAddress: String {
        var parts: [String] = []
        if !address.isEmpty { parts.append(address) }
        if !zipCode.isEmpty || !city.isEmpty {
            let cityPart = [zipCode, city].filter { !$0.isEmpty }.joined(separator: " ")
            parts.append(cityPart)
        }
        return parts.joined(separator: ", ")
    }
    
    var displayName: String {
        if !contactPerson.isEmpty {
            return "\(name) (\(contactPerson))"
        }
        return name
    }
    
    init(
        name: String,
        oib: String = "",
        mbs: String = "",
        address: String = "",
        city: String = "",
        zipCode: String = "",
        contactPerson: String = "",
        email: String = "",
        phone: String = "",
        notes: String = ""
    ) {
        self.name = name
        self.oib = oib
        self.mbs = mbs
        self.address = address
        self.city = city
        self.zipCode = zipCode
        self.contactPerson = contactPerson
        self.email = email
        self.phone = phone
        self.notes = notes
        self.createdAt = Date()
    }
}
