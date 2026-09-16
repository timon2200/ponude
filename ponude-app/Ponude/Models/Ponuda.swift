import Foundation
import SwiftData

/// Quote status workflow
enum PonudaStatus: String, Codable, CaseIterable {
    case nacrt = "Nacrt"
    case poslano = "Poslano"
    case prihvaceno = "Prihvaćeno"
    case odbijeno = "Odbijeno"
    
    var icon: String {
        switch self {
        case .nacrt: return "doc.badge.ellipsis"
        case .poslano: return "paperplane.fill"
        case .prihvaceno: return "checkmark.seal.fill"
        case .odbijeno: return "xmark.seal.fill"
        }
    }
    
    var color: String {
        switch self {
        case .nacrt: return "#94A3B8"
        case .poslano: return "#3B82F6"
        case .prihvaceno: return "#22C55E"
        case .odbijeno: return "#EF4444"
        }
    }
}

/// A quote document (ponuda) linking a business profile to a client with line items.
@Model
final class Ponuda {
    var broj: Int                  // Sequential quote number
    var datum: Date                // Issue date
    var mjesto: String             // Location/city
    var rokValjanosti: Int         // Validity in days
    var napomena: String           // Additional notes
    /// PDF language: "hr" or "en". Optional so existing stores migrate cleanly
    /// (a mandatory attribute with a Swift-side default fails lightweight
    /// migration — Core Data never sees the default).
    var jezik: String?
    var statusRaw: String          // Persisted as raw string
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var businessProfile: BusinessProfile?
    var client: Client?
    
    @Relationship(deleteRule: .cascade, inverse: \PonudaStavka.ponuda)
    var stavke: [PonudaStavka] = []
    
    // Computed properties
    var status: PonudaStatus {
        get { PonudaStatus(rawValue: statusRaw) ?? .nacrt }
        set { statusRaw = newValue.rawValue }
    }

    /// PDF template language; nil on quotes written before languages existed.
    var language: String { jezik ?? "hr" }
    
    var sortedStavke: [PonudaStavka] {
        stavke.sorted { $0.redniBroj < $1.redniBroj }
    }
    
    var ukupno: Decimal {
        stavke.reduce(Decimal.zero) { $0 + $1.vrijednost }
    }
    
    var formattedUkupno: String {
        ukupno.hrFormatted
    }
    
    var displayTitle: String {
        "Ponuda #\(broj)"
    }
    
    init(
        broj: Int,
        datum: Date = Date(),
        mjesto: String = "",
        rokValjanosti: Int = 30,
        napomena: String = "",
        jezik: String = "hr"
    ) {
        self.broj = broj
        self.datum = datum
        self.mjesto = mjesto
        self.rokValjanosti = rokValjanosti
        self.napomena = napomena
        self.jezik = jezik
        self.statusRaw = PonudaStatus.nacrt.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// A single line item in a quote.
@Model
final class PonudaStavka {
    var redniBroj: Int            // Order index
    var naziv: String             // Service name
    var opis: String              // Description (shown below name)
    var kolicina: Decimal         // Quantity
    var cijena: Decimal           // Unit price in EUR
    
    var ponuda: Ponuda?
    
    var vrijednost: Decimal {
        kolicina * cijena
    }
    
    var formattedCijena: String {
        cijena.hrFormatted
    }
    
    var formattedVrijednost: String {
        vrijednost.hrFormatted
    }
    
    init(
        redniBroj: Int,
        naziv: String = "",
        opis: String = "",
        kolicina: Decimal = 1,
        cijena: Decimal = 0
    ) {
        self.redniBroj = redniBroj
        self.naziv = naziv
        self.opis = opis
        self.kolicina = kolicina
        self.cijena = cijena
    }
}
