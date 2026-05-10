import SwiftUI
import Foundation

/// Observable state object for the invoice builder.
/// Holds all editing state as Strings for clean text field binding,
/// and provides computed Decimal values for calculations and the preview.
@Observable
final class InvoiceBuilderState {
    var selectedClient: Client?
    var mjesto: String
    var datum: Date
    var rokPlacanja: String
    var napomena: String
    var stavke: [StavkaEditItem]
    var sourcePonudaBroj: Int
    var isSaving = false
    var showSaveSuccess = false
    var showExportSuccess = false
    
    /// Initialize from an existing Racun or fresh defaults
    init(racun: Racun? = nil, defaultMjesto: String = "") {
        if let r = racun {
            self.selectedClient = r.client
            self.mjesto = r.mjesto
            self.datum = r.datum
            self.rokPlacanja = "\(r.rokPlacanja)"
            self.napomena = r.napomena
            self.sourcePonudaBroj = r.sourcePonudaBroj
            self.stavke = r.sortedStavke.map { stavka in
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
            self.rokPlacanja = "15"
            self.napomena = ""
            self.sourcePonudaBroj = 0
            self.stavke = [StavkaEditItem()]
        }
    }
    
    /// Initialize pre-populated from a Ponuda (for "Kreiraj račun" flow)
    init(fromPonuda ponuda: Ponuda, defaultMjesto: String = "") {
        self.selectedClient = ponuda.client
        self.mjesto = ponuda.mjesto.isEmpty ? defaultMjesto : ponuda.mjesto
        self.datum = Date()
        self.rokPlacanja = "15"
        self.napomena = ponuda.napomena
        self.sourcePonudaBroj = ponuda.broj
        self.stavke = ponuda.sortedStavke.map { stavka in
            StavkaEditItem(
                naziv: stavka.naziv,
                opis: stavka.opis,
                kolicina: stavka.kolicina == 1 ? "1" : stavka.kolicina.hrFormatted,
                cijena: stavka.cijena.hrFormatted
            )
        }
        if self.stavke.isEmpty {
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
    
    var rokPlacanjaDays: Int {
        Int(rokPlacanja) ?? 15
    }
    
    /// Calculated payment due date
    var rokPlacanjaDate: Date {
        Calendar.current.date(byAdding: .day, value: rokPlacanjaDays, to: datum) ?? datum
    }
    
    var isValid: Bool {
        selectedClient != nil && !stavke.isEmpty && stavke.contains(where: { !$0.naziv.isEmpty })
    }
    
    var hasSourcePonuda: Bool {
        sourcePonudaBroj > 0
    }
    
    /// A lightweight token that changes whenever any editable state changes.
    /// Used by DebouncedInvoicePreviewWrapper to detect mutations without deep comparison.
    var changeToken: Int {
        var hasher = Hasher()
        hasher.combine(selectedClient?.id)
        hasher.combine(mjesto)
        hasher.combine(datum)
        hasher.combine(rokPlacanja)
        hasher.combine(napomena)
        hasher.combine(sourcePonudaBroj)
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
