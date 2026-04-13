import SwiftUI
import Foundation

/// Observable state object for the quote builder.
/// Holds all editing state as Strings for clean text field binding,
/// and provides computed Decimal values for calculations and the preview.
@Observable
final class QuoteBuilderState {
    var selectedClient: Client?
    var mjesto: String
    var datum: Date
    var rokValjanosti: String
    var napomena: String
    var stavke: [StavkaEditItem]
    var isSaving = false
    var showSaveSuccess = false
    var showExportSuccess = false
    
    /// Initialize from an existing Ponuda or fresh defaults
    init(ponuda: Ponuda? = nil, defaultMjesto: String = "") {
        if let p = ponuda {
            self.selectedClient = p.client
            self.mjesto = p.mjesto
            self.datum = p.datum
            self.rokValjanosti = "\(p.rokValjanosti)"
            self.napomena = p.napomena
            self.stavke = p.sortedStavke.map { stavka in
                StavkaEditItem(
                    naziv: stavka.naziv,
                    opis: stavka.opis,
                    kolicina: stavka.kolicina == 1 ? "1" : stavka.kolicina.hrFormatted,
                    cijena: stavka.cijena.hrFormatted
                )
            }
        } else {
            self.selectedClient = nil
            self.mjesto = defaultMjesto
            self.datum = Date()
            self.rokValjanosti = "30"
            self.napomena = ""
            self.stavke = [StavkaEditItem()]
        }
    }
    
    // MARK: - Computed
    
    var ukupno: Decimal {
        stavke.reduce(Decimal.zero) { $0 + $1.vrijednost }
    }
    
    var formattedUkupno: String {
        ukupno.hrFormatted
    }
    
    var rokValjanostiDays: Int {
        Int(rokValjanosti) ?? 30
    }
    
    var isValid: Bool {
        selectedClient != nil && !stavke.isEmpty && stavke.contains(where: { !$0.naziv.isEmpty })
    }
    
    /// A lightweight token that changes whenever any editable state changes.
    /// Used by DebouncedPreviewWrapper to detect mutations without deep comparison.
    var changeToken: Int {
        var hasher = Hasher()
        hasher.combine(selectedClient?.id)
        hasher.combine(mjesto)
        hasher.combine(datum)
        hasher.combine(rokValjanosti)
        hasher.combine(napomena)
        for s in stavke {
            hasher.combine(s.naziv)
            hasher.combine(s.opis)
            hasher.combine(s.kolicina)
            hasher.combine(s.cijena)
        }
        return hasher.finalize()
    }
    
    // MARK: - Actions
    
    func addStavka() {
        let newItem = StavkaEditItem()
        stavke.append(newItem)
    }
    
    func removeStavka(at offsets: IndexSet) {
        stavke.remove(atOffsets: offsets)
        if stavke.isEmpty {
            stavke.append(StavkaEditItem())
        }
    }
    
    func removeStavka(_ item: StavkaEditItem) {
        stavke.removeAll { $0.id == item.id }
        if stavke.isEmpty {
            stavke.append(StavkaEditItem())
        }
    }
    
    func moveStavka(from source: IndexSet, to destination: Int) {
        stavke.move(fromOffsets: source, toOffset: destination)
    }
}

/// A single editable line item with String-based fields for text field binding.
@Observable
final class StavkaEditItem: Identifiable {
    let id = UUID()
    var naziv: String
    var opis: String
    var kolicina: String
    var cijena: String
    var isDescriptionExpanded: Bool
    
    init(naziv: String = "", opis: String = "", kolicina: String = "1", cijena: String = "") {
        self.naziv = naziv
        self.opis = opis
        self.kolicina = kolicina
        self.cijena = cijena
        self.isDescriptionExpanded = !opis.isEmpty
    }
    
    var kolicinaDecimal: Decimal {
        kolicina.toDecimal == 0 ? 1 : kolicina.toDecimal
    }
    
    var cijenaDecimal: Decimal {
        cijena.toDecimal
    }
    
    var vrijednost: Decimal {
        kolicinaDecimal * cijenaDecimal
    }
    
    var formattedVrijednost: String {
        vrijednost.hrFormatted
    }
}
