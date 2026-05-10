import Foundation
import SwiftData

/// Invoice status workflow
enum RacunStatus: String, Codable, CaseIterable {
    case nacrt = "Nacrt"
    case izdano = "Izdano"
    case placeno = "Plaćeno"
    case stornirano = "Stornirano"
    
    var icon: String {
        switch self {
        case .nacrt: return "doc.badge.ellipsis"
        case .izdano: return "paperplane.fill"
        case .placeno: return "checkmark.seal.fill"
        case .stornirano: return "xmark.seal.fill"
        }
    }
    
    var color: String {
        switch self {
        case .nacrt: return "#94A3B8"
        case .izdano: return "#8B5CF6"
        case .placeno: return "#22C55E"
        case .stornirano: return "#EF4444"
        }
    }
}

/// An invoice document (račun) linking a business profile to a client with line items.
@Model
final class Racun {
    var broj: Int                  // Sequential invoice number
    var datum: Date                // Issue date
    var mjesto: String             // Location/city
    var rokPlacanja: Int           // Payment deadline in days
    var napomena: String           // Additional notes
    var statusRaw: String          // Persisted as raw string
    var sourcePonudaBroj: Int      // 0 means no source ponuda
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var businessProfile: BusinessProfile?
    var client: Client?
    
    @Relationship(deleteRule: .cascade, inverse: \RacunStavka.racun)
    var stavke: [RacunStavka] = []
    
    // Computed properties
    var status: RacunStatus {
        get { RacunStatus(rawValue: statusRaw) ?? .nacrt }
        set { statusRaw = newValue.rawValue }
    }
    
    var sortedStavke: [RacunStavka] {
        stavke.sorted { $0.redniBroj < $1.redniBroj }
    }
    
    var ukupno: Decimal {
        stavke.reduce(Decimal.zero) { $0 + $1.vrijednost }
    }
    
    var formattedUkupno: String {
        ukupno.hrFormatted
    }
    
    var displayTitle: String {
        "Račun #\(broj)"
    }
    
    /// Formatted invoice number with year: "1/2026"
    var formattedBroj: String {
        let year = Calendar.current.component(.year, from: datum)
        return "\(broj)/\(year)"
    }
    
    /// Calculated payment due date
    var rokPlacanjaDate: Date {
        Calendar.current.date(byAdding: .day, value: rokPlacanja, to: datum) ?? datum
    }
    
    /// Whether this invoice was created from a ponuda
    var hasSourcePonuda: Bool {
        sourcePonudaBroj > 0
    }
    
    init(
        broj: Int,
        datum: Date = Date(),
        mjesto: String = "",
        rokPlacanja: Int = 15,
        napomena: String = "",
        sourcePonudaBroj: Int = 0
    ) {
        self.broj = broj
        self.datum = datum
        self.mjesto = mjesto
        self.rokPlacanja = rokPlacanja
        self.napomena = napomena
        self.sourcePonudaBroj = sourcePonudaBroj
        self.statusRaw = RacunStatus.nacrt.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// A single line item in an invoice.
@Model
final class RacunStavka {
    var redniBroj: Int            // Order index
    var naziv: String             // Service name
    var opis: String              // Description (shown below name)
    var kolicina: Decimal         // Quantity
    var cijena: Decimal           // Unit price in EUR
    
    var racun: Racun?
    
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
