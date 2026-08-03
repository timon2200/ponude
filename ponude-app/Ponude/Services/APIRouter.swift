import Foundation
import SwiftData

/// Maps HTTP requests onto the app's SwiftData store.
///
/// Everything here runs on the main actor against the app's own `mainContext`,
/// which is what keeps the running UI in sync: inserting a `Ponuda` here makes
/// the dashboard's `@Query` refresh immediately, exactly as if the user had
/// pressed Save in the builder.
@MainActor
enum Router {

    private static var context: ModelContext { PonudaApp.sharedModelContainer.mainContext }

    // MARK: - Entry point

    static func handle(_ request: HTTPRequest) async -> HTTPResponse {
        let segments = request.path.split(separator: "/").map(String.init)

        // Health is deliberately unauthenticated so a bridge can report
        // "app not running" separately from "token wrong".
        if request.method == "GET", segments == ["health"] {
            return .json(["ok": true, "app": "Ponude", "api": 1])
        }

        guard let token = request.bearerToken, constantTimeEquals(token, APIToken.current) else {
            return .error(401, "Missing or invalid bearer token")
        }

        switch (request.method, segments.first, segments.count) {
        case ("GET", "profiles", 1):
            return listProfiles()

        case ("GET", "clients", 1):
            return listClients(query: request.query["q"] ?? "")

        case ("POST", "clients", 1):
            return createClient(request.json)

        case ("GET", "ponude", 1):
            return listPonude(
                profile: request.query["profile"],
                limit: Int(request.query["limit"] ?? "") ?? 50
            )

        case ("POST", "ponude", 1):
            return createPonuda(request.json)

        case ("GET", "ponude", 2):
            let id = segments[1]
            guard let match = findPonuda(id: id) else { return .error(404, "No quote with id \(id)") }
            return .json(detail(match))

        case ("POST", "ponude", 3) where segments[2] == "pdf":
            return await exportPDF(id: segments[1], body: request.json)

        default:
            return .error(404, "No route for \(request.method) \(request.path)")
        }
    }

    // MARK: - Profiles

    private static func listProfiles() -> HTTPResponse {
        let profiles = (try? context.fetch(FetchDescriptor<BusinessProfile>())) ?? []
        return .json([
            "profiles": profiles.map { profile in
                [
                    "id": IDCodec.encode(profile.persistentModelID),
                    "name": profile.name,
                    "short_name": profile.shortName,
                    "owner_name": profile.ownerName,
                    "oib": profile.oib,
                    "city": profile.city,
                    "tax_status": profile.taxStatus.rawValue,
                    "is_default": profile.isDefault
                ]
            }
        ])
    }

    // MARK: - Clients

    private static func listClients(query: String) -> HTTPResponse {
        var clients = (try? context.fetch(FetchDescriptor<Client>(sortBy: [SortDescriptor(\.name)]))) ?? []

        // Same shape as the in-app search: every whitespace-separated token has
        // to appear somewhere, so "turis kop" finds "Turistička zajednica grada
        // Koprivnice" without the user typing it out.
        let tokens = query.folded.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if !tokens.isEmpty {
            clients = clients.filter { client in
                let haystack = "\(client.name) \(client.oib) \(client.city) \(client.contactPerson)".folded
                return tokens.allSatisfy { haystack.contains($0) }
            }
        }

        return .json(["clients": clients.map(summary)])
    }

    private static func createClient(_ body: [String: Any]) -> HTTPResponse {
        guard let name = (body["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return .error(400, "Field 'name' is required")
        }

        let oib = (body["oib"] as? String) ?? ""

        // An OIB is unique per legal entity, so treat a repeat as "you meant the
        // existing one" rather than creating a duplicate the user has to clean up.
        if !oib.isEmpty {
            let existing = (try? context.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.oib == oib })))?.first
            if let existing {
                return .json(["client": summary(existing), "created": false])
            }
        }

        let client = Client(
            name: name,
            oib: oib,
            mbs: (body["mbs"] as? String) ?? "",
            address: (body["address"] as? String) ?? "",
            city: (body["city"] as? String) ?? "",
            zipCode: (body["zip_code"] as? String) ?? "",
            contactPerson: (body["contact_person"] as? String) ?? "",
            email: (body["email"] as? String) ?? "",
            phone: (body["phone"] as? String) ?? "",
            notes: (body["notes"] as? String) ?? ""
        )
        context.insert(client)

        if let message = Persistence.saveOrError(context, "API create client \(name)") {
            return .error(500, message)
        }
        return .json(["client": summary(client), "created": true], status: 201)
    }

    private static func summary(_ client: Client) -> [String: Any] {
        [
            "id": IDCodec.encode(client.persistentModelID),
            "name": client.name,
            "oib": client.oib,
            "address": client.address,
            "city": client.city,
            "zip_code": client.zipCode,
            "contact_person": client.contactPerson,
            "email": client.email,
            "phone": client.phone
        ]
    }

    // MARK: - Quotes

    private static func listPonude(profile: String?, limit: Int) -> HTTPResponse {
        var ponude = (try? context.fetch(
            FetchDescriptor<Ponuda>(sortBy: [SortDescriptor(\.broj, order: .reverse)])
        )) ?? []

        if let profile, !profile.isEmpty {
            guard let match = resolveProfile(profile) else {
                return .error(404, "No business profile matching '\(profile)'")
            }
            ponude = ponude.filter { $0.businessProfile?.persistentModelID == match.persistentModelID }
        }

        return .json(["ponude": ponude.prefix(max(1, limit)).map(summary)])
    }

    private static func createPonuda(_ body: [String: Any]) -> HTTPResponse {
        // Business profile — the issuer. Required, because it decides both the
        // numbering sequence and which PDF template the quote renders with.
        guard let profileKey = body["profile"] as? String ?? body["profile_id"] as? String else {
            return .error(400, "Field 'profile' is required (name, short name, OIB, or id)")
        }
        guard let profile = resolveProfile(profileKey) else {
            return .error(404, "No business profile matching '\(profileKey)'")
        }

        guard let client = resolveClient(body) else {
            return .error(404, "No client matching the given client_id / client_oib / client_name")
        }

        guard let rawStavke = body["stavke"] as? [[String: Any]], !rawStavke.isEmpty else {
            return .error(400, "Field 'stavke' must be a non-empty array of line items")
        }

        var items: [(naziv: String, opis: String, kolicina: Decimal, cijena: Decimal)] = []
        for (index, raw) in rawStavke.enumerated() {
            guard let naziv = (raw["naziv"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !naziv.isEmpty else {
                return .error(400, "stavke[\(index)] is missing 'naziv'")
            }
            guard let cijena = Parse.decimal(raw["cijena"]) else {
                return .error(400, "stavke[\(index)] has a missing or unparseable 'cijena'")
            }
            items.append((
                naziv: naziv,
                opis: (raw["opis"] as? String) ?? "",
                kolicina: Parse.decimal(raw["kolicina"]) ?? 1,
                cijena: cijena
            ))
        }

        // Numbering mirrors the builder: next number in this profile's own
        // sequence, unless the caller pins one explicitly.
        let broj: Int
        if let requested = body["broj"] as? Int {
            broj = requested
        } else {
            let existing = profile.ponude.map(\.broj).max() ?? 0
            broj = existing + 1
        }

        let ponuda = Ponuda(
            broj: broj,
            datum: Parse.date(body["datum"]) ?? Date(),
            mjesto: (body["mjesto"] as? String) ?? profile.city,
            rokValjanosti: body["rok_valjanosti"] as? Int ?? 30,
            napomena: (body["napomena"] as? String) ?? ""
        )
        if let statusRaw = body["status"] as? String, let status = PonudaStatus(rawValue: statusRaw) {
            ponuda.status = status
        }
        ponuda.businessProfile = profile
        ponuda.client = client
        context.insert(ponuda)

        for (index, item) in items.enumerated() {
            let stavka = PonudaStavka(
                redniBroj: index + 1,
                naziv: item.naziv,
                opis: item.opis,
                kolicina: item.kolicina,
                cijena: item.cijena
            )
            stavka.ponuda = ponuda
            context.insert(stavka)
        }

        if let message = Persistence.saveOrError(context, "API create Ponuda #\(broj)") {
            return .error(500, message)
        }

        LocalAPIServer.log.info("Created Ponuda #\(broj, privacy: .public) via API")
        return .json(["ponuda": detail(ponuda)], status: 201)
    }

    private static func summary(_ ponuda: Ponuda) -> [String: Any] {
        [
            "id": IDCodec.encode(ponuda.persistentModelID),
            "broj": ponuda.broj,
            "datum": Parse.isoDay.string(from: ponuda.datum),
            "status": ponuda.status.rawValue,
            "client": ponuda.client?.name ?? "",
            "profile": ponuda.businessProfile?.shortName ?? "",
            "ukupno": (ponuda.ukupno as NSDecimalNumber).doubleValue,
            "ukupno_formatted": ponuda.formattedUkupno
        ]
    }

    private static func detail(_ ponuda: Ponuda) -> [String: Any] {
        var payload = summary(ponuda)
        payload["mjesto"] = ponuda.mjesto
        payload["rok_valjanosti"] = ponuda.rokValjanosti
        payload["napomena"] = ponuda.napomena
        payload["client_oib"] = ponuda.client?.oib ?? ""
        payload["stavke"] = ponuda.sortedStavke.map { stavka in
            [
                "redni_broj": stavka.redniBroj,
                "naziv": stavka.naziv,
                "opis": stavka.opis,
                "kolicina": (stavka.kolicina as NSDecimalNumber).doubleValue,
                "cijena": (stavka.cijena as NSDecimalNumber).doubleValue,
                "vrijednost": (stavka.vrijednost as NSDecimalNumber).doubleValue
            ] as [String: Any]
        }
        return payload
    }

    // MARK: - PDF export

    private static func exportPDF(id: String, body: [String: Any]) async -> HTTPResponse {
        guard let ponuda = findPonuda(id: id) else { return .error(404, "No quote with id \(id)") }
        guard let profile = ponuda.businessProfile else {
            return .error(400, "Quote #\(ponuda.broj) has no business profile, so it cannot be rendered")
        }

        let destination: URL
        if let path = body["path"] as? String, !path.isEmpty {
            destination = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let name = "\(ponuda.broj)-Ponuda_\(formatter.string(from: Date())).pdf"
            destination = FileManager.default
                .urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(name)
        }

        // The generator takes the builder's editing types, so map the stored
        // line items back into them rather than duplicating template logic.
        let stavke = ponuda.sortedStavke.map { stavka in
            StavkaEditItem(
                naziv: stavka.naziv,
                opis: stavka.opis,
                kolicina: stavka.kolicina.hrFormatted,
                cijena: stavka.cijena.hrFormatted
            )
        }

        do {
            let url = try await PDFGenerator().exportQuoteToFile(
                businessProfile: profile,
                client: ponuda.client,
                ponudaBroj: ponuda.broj,
                datum: ponuda.datum,
                mjesto: ponuda.mjesto,
                stavke: stavke,
                ukupno: ponuda.ukupno,
                napomena: ponuda.napomena,
                rokValjanosti: ponuda.rokValjanosti,
                to: destination
            )
            return .json(["path": url.path, "broj": ponuda.broj])
        } catch {
            return .error(500, error.localizedDescription)
        }
    }

    // MARK: - Lookup helpers

    private static func findPonuda(id: String) -> Ponuda? {
        guard let identifier = IDCodec.decode(id) else { return nil }
        return context.model(for: identifier) as? Ponuda
    }

    /// Resolves a profile from an opaque id or, more usefully for an agent, from
    /// a human name: "Lotus RC", "lotus", or an OIB all work.
    private static func resolveProfile(_ key: String) -> BusinessProfile? {
        if let identifier = IDCodec.decode(key), let profile = context.model(for: identifier) as? BusinessProfile {
            return profile
        }

        let profiles = (try? context.fetch(FetchDescriptor<BusinessProfile>())) ?? []
        let needle = key.folded

        if let exact = profiles.first(where: { $0.shortName.folded == needle || $0.name.folded == needle || $0.oib == key }) {
            return exact
        }
        return profiles.first { $0.shortName.folded.contains(needle) || $0.name.folded.contains(needle) }
    }

    private static func resolveClient(_ body: [String: Any]) -> Client? {
        if let id = body["client_id"] as? String,
           let identifier = IDCodec.decode(id),
           let client = context.model(for: identifier) as? Client {
            return client
        }

        let clients = (try? context.fetch(FetchDescriptor<Client>())) ?? []

        if let oib = body["client_oib"] as? String, !oib.isEmpty {
            return clients.first { $0.oib == oib }
        }

        if let name = body["client_name"] as? String, !name.isEmpty {
            let needle = name.folded
            if let exact = clients.first(where: { $0.name.folded == needle }) { return exact }
            let matches = clients.filter { $0.name.folded.contains(needle) }
            // Only accept a fuzzy hit when it is unambiguous — silently billing
            // the wrong company is far worse than making the agent be specific.
            return matches.count == 1 ? matches[0] : nil
        }

        return nil
    }

    /// Compares tokens without leaking length or prefix through timing.
    private static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8), b = Array(rhs.utf8)
        guard a.count == b.count else { return false }
        var difference: UInt8 = 0
        for index in a.indices { difference |= a[index] ^ b[index] }
        return difference == 0
    }
}

// MARK: - Identifier encoding

/// Turns a `PersistentIdentifier` into a string an agent can round-trip.
/// SwiftData ids are `Codable` but not textual, so JSON-encode then base64 them.
enum IDCodec {
    static func encode(_ id: PersistentIdentifier) -> String {
        guard let data = try? JSONEncoder().encode(id) else { return "" }
        return data.base64EncodedString()
    }

    static func decode(_ string: String) -> PersistentIdentifier? {
        guard let data = Data(base64Encoded: string) else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }
}

// MARK: - Input parsing

enum Parse {

    static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    /// Accepts JSON numbers as well as strings in either plain ("1234.50") or
    /// Croatian ("1.234,50") notation, since an agent may echo back a formatted
    /// value it read from the app.
    static func decimal(_ value: Any?) -> Decimal? {
        switch value {
        case let number as NSNumber:
            // Via the string form: `Decimal(double:)` would inherit binary
            // floating-point error on values like 0.1.
            return Decimal(string: number.stringValue)
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return nil }
            if trimmed.contains(",") { return trimmed.toDecimal }
            return Decimal(string: trimmed)
        default:
            return nil
        }
    }

    /// Accepts "yyyy-MM-dd" or a full ISO 8601 timestamp.
    static func date(_ value: Any?) -> Date? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        if let day = isoDay.date(from: string) { return day }
        return ISO8601DateFormatter().date(from: string)
    }
}

// MARK: - Matching helpers

extension String {
    /// Lowercased and stripped of diacritics, so "Varaždin" matches "varazdin".
    var folded: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "hr_HR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
