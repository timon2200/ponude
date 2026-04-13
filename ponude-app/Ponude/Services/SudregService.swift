import Foundation

/// Data model for a subject returned from the Sudreg API
struct SudregSubject: Identifiable {
    var id: String { mbs }
    let mbs: String
    let oib: String
    let naziv: String
    let adresa: String
    let mjesto: String
    let postanskiBroj: String
}

/// OAuth2 token response from Sudreg
private struct TokenResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

/// Service for querying the Croatian Court Register (Sudski registar)
/// API: https://sudreg-data.gov.hr (v3.0.4)
///
/// Flow:
/// 1. Search by name via /api/javni/subjekti?tvrtka_naziv=%query%
///    → Returns MBS + OIB (integer) but NO name/address
/// 2. Fetch full details via /api/javni/detalji_subjekta?tip_identifikatora=mbs&identifikator=...
///    → Returns tvrtka.ime, sjediste.ulica, potpuni_oib, etc.
///
/// Requires OAuth2 credentials (Client ID + Client Secret) obtained
/// through registration at sudreg-data.gov.hr
final class SudregService: @unchecked Sendable {
    private let baseURL = "https://sudreg-data.gov.hr"
    private let tokenURL = "https://sudreg-data.gov.hr/api/oauth/token"
    private let subjectsURL = "https://sudreg-data.gov.hr/api/javni/subjekti"
    private let detailsURL = "https://sudreg-data.gov.hr/api/javni/detalji_subjekta"
    
    private var accessToken: String?
    private var tokenExpiry: Date?
    
    private var clientId: String {
        UserDefaults.standard.string(forKey: "sudregClientId") ?? ""
    }
    
    private var clientSecret: String {
        UserDefaults.standard.string(forKey: "sudregClientSecret") ?? ""
    }
    
    var isConfigured: Bool {
        !clientId.isEmpty && !clientSecret.isEmpty
    }
    
    // MARK: - Public API
    
    /// Search for business subjects by name or OIB.
    /// Returns subjects with full details (address, OIB) populated via the detalji_subjekta endpoint.
    func searchSubjects(query: String) async -> [SudregSubject] {
        guard isConfigured else {
            print("[Sudreg] API credentials not configured")
            return []
        }
        
        guard await ensureValidToken() else {
            print("[Sudreg] Failed to obtain access token")
            return []
        }
        
        do {
            // Step 1: Search for subjects — returns MBS + OIB but no name/address
            let searchResults = try await searchSubjectsBasic(query: query)
            
            if searchResults.isEmpty {
                print("[Sudreg] No search results for: \(query)")
                return []
            }
            
            // Step 2: Fetch full details for each result (name, address, OIB string, etc.)
            // The search endpoint only returns MBS + OIB (integer), so we MUST fetch details
            // to get the company name and address.
            var detailedSubjects: [SudregSubject] = []
            
            // Limit to first 10 to avoid excessive API calls
            let limitedResults = Array(searchResults.prefix(10))
            
            for result in limitedResults {
                if let detailed = try? await fetchSubjectDetails(mbs: result.mbs, fallbackName: result.naziv) {
                    detailedSubjects.append(detailed)
                } else {
                    // Use the basic data if details fetch fails
                    detailedSubjects.append(result)
                }
            }
            
            print("[Sudreg] Returning \(detailedSubjects.count) detailed results")
            return detailedSubjects
            
        } catch {
            print("[Sudreg] Search error: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Test if the API connection works with current credentials
    func testConnection() async -> Bool {
        guard isConfigured else { return false }
        return await ensureValidToken()
    }
    
    // MARK: - Step 1: Basic Search (/subjekti)
    
    /// Search subjects by name or OIB. Returns basic results (MBS + OIB).
    /// NOTE: The v3 API's /subjekti endpoint does NOT return company names or addresses;
    /// it only returns MBS, status, OIB (integer), and other numeric fields.
    /// The `tvrtka_naziv` parameter uses SQL LIKE matching — wrap with % for partial match.
    private func searchSubjectsBasic(query: String) async throws -> [SudregSubject] {
        let isOIB = query.count == 11 && query.allSatisfy(\.isNumber)
        
        var components = URLComponents(string: subjectsURL)!
        components.queryItems = [
            URLQueryItem(name: "only_active", value: "true"),
            URLQueryItem(name: "limit", value: "15"),
            // Return empty array instead of HTTP 400 error on no results
            URLQueryItem(name: "no_data_error", value: "0"),
            URLQueryItem(name: "omit_nulls", value: "true"),
        ]
        
        if isOIB {
            // For OIB search, use detalji_subjekta directly since it supports OIB lookup
            return try await searchByOIB(oib: query)
        } else {
            // Wrap with SQL LIKE wildcards for partial name matching
            // The API uses Oracle LIKE syntax: %query% matches anywhere in the name
            let searchTerm = "%\(query)%"
            components.queryItems?.append(URLQueryItem(name: "tvrtka_naziv", value: searchTerm))
        }
        
        guard let url = components.url else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[Sudreg] Invalid response type")
            return []
        }
        
        print("[Sudreg] Search response status: \(httpResponse.statusCode)")
        
        // With no_data_error=0, empty results return 200 with empty body
        if data.isEmpty {
            print("[Sudreg] Empty response (no results)")
            return []
        }
        
        guard httpResponse.statusCode == 200 else {
            if let body = String(data: data, encoding: .utf8) {
                print("[Sudreg] Search error body: \(body.prefix(500))")
            }
            return []
        }
        
        return parseSearchResults(from: data)
    }
    
    /// Search by OIB directly using the detalji_subjekta endpoint
    private func searchByOIB(oib: String) async throws -> [SudregSubject] {
        if let result = try await fetchSubjectDetails(identifierType: "oib", identifier: oib) {
            return [result]
        }
        return []
    }
    
    // MARK: - Step 2: Fetch Details (/detalji_subjekta)
    
    /// Fetch full details for a specific subject by MBS.
    /// Returns the complete subject with name, OIB, address, city, postal code.
    private func fetchSubjectDetails(mbs: String, fallbackName: String) async throws -> SudregSubject? {
        return try await fetchSubjectDetails(identifierType: "mbs", identifier: mbs, fallbackName: fallbackName)
    }
    
    /// Fetch full details using either MBS or OIB as identifier.
    private func fetchSubjectDetails(identifierType: String = "mbs", identifier: String, fallbackName: String = "") async throws -> SudregSubject? {
        var components = URLComponents(string: detailsURL)!
        components.queryItems = [
            URLQueryItem(name: "tip_identifikatora", value: identifierType),
            URLQueryItem(name: "identifikator", value: identifier),
            URLQueryItem(name: "expand_relations", value: "true"),
            URLQueryItem(name: "omit_nulls", value: "true"),
            URLQueryItem(name: "no_data_error", value: "0"),
        ]
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[Sudreg] Details: invalid response type")
            return nil
        }
        
        if data.isEmpty {
            print("[Sudreg] Details: empty response for \(identifierType)=\(identifier)")
            return nil
        }
        
        guard httpResponse.statusCode == 200 else {
            print("[Sudreg] Details fetch failed for \(identifierType)=\(identifier), status: \(httpResponse.statusCode)")
            return nil
        }
        
        return parseSubjectDetails(from: data, mbs: identifierType == "mbs" ? identifier : "", fallbackName: fallbackName)
    }
    
    // MARK: - OAuth2 Token Management
    
    private func ensureValidToken() async -> Bool {
        // Check if existing token is still valid (with 60s buffer)
        if let _ = accessToken, let expiry = tokenExpiry,
           Date() < expiry.addingTimeInterval(-60) {
            return true
        }
        
        return await fetchNewToken()
    }
    
    private func fetchNewToken() async -> Bool {
        guard let url = URL(string: tokenURL) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic auth header: base64(clientId:clientSecret)
        let credentials = "\(clientId):\(clientSecret)"
        if let credData = credentials.data(using: .utf8) {
            request.setValue("Basic \(credData.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[Sudreg] Token request failed with status: \(statusCode)")
                if let body = String(data: data, encoding: .utf8) {
                    print("[Sudreg] Token error body: \(body.prefix(300))")
                }
                return false
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            accessToken = tokenResponse.access_token
            tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
            
            print("[Sudreg] Token obtained, expires in \(tokenResponse.expires_in)s")
            return true
        } catch {
            print("[Sudreg] Token error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Response Parsing
    
    /// Parse the search results from /subjekti endpoint.
    /// v3 API response format: an array of flat objects with numeric fields.
    /// Example item: { "mbs": 30068231, "status": 1, "oib": 5989383998, "mb": 1514806, ... }
    /// NOTE: Fields like mbs, oib, mb are INTEGERS, not strings.
    /// NOTE: No company name or address is included — those come from /detalji_subjekta.
    private func parseSearchResults(from data: Data) -> [SudregSubject] {
        do {
            // Debug: log a snippet of the raw response
            if let rawString = String(data: data, encoding: .utf8) {
                print("[Sudreg] Raw search response (first 800 chars): \(rawString.prefix(800))")
            }
            
            // Try parsing as JSON
            let jsonObj = try JSONSerialization.jsonObject(with: data)
            
            // v3 API returns a flat array: [ { "mbs": int, "oib": int, ... }, ... ]
            let items: [[String: Any]]
            
            if let array = jsonObj as? [[String: Any]] {
                items = array
            } else if let dict = jsonObj as? [String: Any] {
                // Check if it's an error response
                if dict["error_code"] != nil {
                    print("[Sudreg] API returned error: \(dict["error_message"] ?? "unknown")")
                    return []
                }
                // Try common wrapper keys (legacy compatibility)
                if let dataArray = dict["data"] as? [[String: Any]] {
                    items = dataArray
                } else {
                    // Single result
                    items = [dict]
                }
            } else {
                print("[Sudreg] Unexpected JSON structure")
                return []
            }
            
            print("[Sudreg] Found \(items.count) search results to parse")
            
            return items.compactMap { item -> SudregSubject? in
                // MBS is the primary key — required (v3 returns it as integer)
                let mbs: String
                if let mbsInt = item["mbs"] as? Int {
                    mbs = String(mbsInt)
                } else if let mbsInt64 = item["mbs"] as? Int64 {
                    mbs = String(mbsInt64)
                } else if let mbsStr = item["mbs"] as? String {
                    mbs = mbsStr
                } else {
                    return nil
                }
                
                // OIB — v3 returns as integer, may need zero-padding to 11 digits
                let oib: String
                if let oibInt = item["oib"] as? Int {
                    oib = String(format: "%011d", oibInt)
                } else if let oibInt64 = item["oib"] as? Int64 {
                    oib = String(format: "%011lld", oibInt64)
                } else if let oibStr = item["oib"] as? String {
                    oib = oibStr
                } else if let potpuniOib = item["potpuni_oib"] as? String {
                    oib = potpuniOib
                } else {
                    oib = ""
                }
                
                // The /subjekti endpoint does NOT return company name.
                // Use "MBS: xxxxxx" as placeholder — will be replaced by details fetch.
                let naziv = "MBS: \(mbs)"
                
                return SudregSubject(
                    mbs: mbs,
                    oib: oib,
                    naziv: naziv,
                    adresa: "",
                    mjesto: "",
                    postanskiBroj: ""
                )
            }
        } catch {
            print("[Sudreg] Parse error: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Parse the detailed subject response from /detalji_subjekta endpoint.
    /// This endpoint returns a single structured object with full information.
    ///
    /// v3 response format:
    /// {
    ///   "mbs": 30068231,
    ///   "oib": 5989383998,          // integer!
    ///   "potpuni_oib": "05989383998", // zero-padded string
    ///   "tvrtka": { "ime": "COMPANY NAME", "naznaka_imena": "SHORT NAME" },
    ///   "sjediste": {
    ///     "ulica": "Street Name",
    ///     "kucni_broj": 42,          // integer!
    ///     "naziv_naselja": "City",
    ///     "sifra_zupanije": 16,
    ///     ...
    ///   },
    ///   ...
    /// }
    private func parseSubjectDetails(from data: Data, mbs: String, fallbackName: String) -> SudregSubject? {
        do {
            // Debug log
            if let rawString = String(data: data, encoding: .utf8) {
                print("[Sudreg] Raw details response (first 800 chars): \(rawString.prefix(800))")
            }
            
            let jsonObj = try JSONSerialization.jsonObject(with: data)
            
            // The details response is a single object
            let item: [String: Any]
            if let dict = jsonObj as? [String: Any] {
                // Check for error response
                if dict["error_code"] != nil {
                    print("[Sudreg] Details API error: \(dict["error_message"] ?? "unknown")")
                    return nil
                }
                item = dict
            } else if let array = jsonObj as? [[String: Any]], let first = array.first {
                item = first
            } else {
                return nil
            }
            
            // Extract MBS (use from response if available, fall back to parameter)
            let resolvedMbs: String
            if let mbsInt = item["mbs"] as? Int {
                resolvedMbs = String(mbsInt)
            } else if let mbsInt64 = item["mbs"] as? Int64 {
                resolvedMbs = String(mbsInt64)
            } else if let mbsStr = item["mbs"] as? String {
                resolvedMbs = mbsStr
            } else {
                resolvedMbs = mbs
            }
            
            // Extract name from nested tvrtka structure
            let naziv: String
            if let tvrtkaDict = item["tvrtka"] as? [String: Any] {
                // v3 format: { "tvrtka": { "ime": "...", "naznaka_imena": "..." } }
                naziv = tvrtkaDict["ime"] as? String
                    ?? tvrtkaDict["naznaka_imena"] as? String
                    ?? fallbackName
            } else if let tvrtkaArray = item["tvrtke"] as? [[String: Any]], let first = tvrtkaArray.first {
                naziv = first["ime"] as? String
                    ?? first["naznaka_imena"] as? String
                    ?? fallbackName
            } else {
                naziv = item["tvrtka"] as? String
                    ?? item["naziv"] as? String
                    ?? fallbackName
            }
            
            // OIB — prefer potpuni_oib (zero-padded string), fall back to integer
            let oib: String
            if let potpuniOib = item["potpuni_oib"] as? String, !potpuniOib.isEmpty {
                oib = potpuniOib
            } else if let oibInt = item["oib"] as? Int {
                oib = String(format: "%011d", oibInt)
            } else if let oibInt64 = item["oib"] as? Int64 {
                oib = String(format: "%011lld", oibInt64)
            } else if let oibStr = item["oib"] as? String {
                oib = oibStr
            } else {
                oib = ""
            }
            
            // Address from sjediste (v3 format: nested object with integer kucni_broj)
            let adresa: String
            let mjesto: String
            let zip: String
            
            if let sjediste = item["sjediste"] as? [String: Any] {
                let ulica = sjediste["ulica"] as? String ?? ""
                
                // kucni_broj can be integer or string in v3
                let kucniBroj: String
                if let kbInt = sjediste["kucni_broj"] as? Int {
                    kucniBroj = String(kbInt)
                } else if let kbStr = sjediste["kucni_broj"] as? String {
                    kucniBroj = kbStr
                } else {
                    kucniBroj = ""
                }
                
                // kucni_podbroj for apartment/suite numbers
                let kucniPodbroj: String
                if let kpStr = sjediste["kucni_podbroj"] as? String, !kpStr.isEmpty {
                    kucniPodbroj = "/\(kpStr)"
                } else {
                    kucniPodbroj = ""
                }
                
                adresa = [ulica, kucniBroj + kucniPodbroj].filter { !$0.isEmpty }.joined(separator: " ")
                mjesto = sjediste["naziv_naselja"] as? String
                    ?? sjediste["naselje"] as? String
                    ?? ""
                
                // postanski_broj may be an integer or string
                if let zipInt = sjediste["postanski_broj"] as? Int {
                    zip = String(zipInt)
                } else {
                    zip = sjediste["postanski_broj"] as? String ?? ""
                }
            } else if let sjedistaArray = item["sjedista"] as? [[String: Any]], let sjediste = sjedistaArray.first {
                let ulica = sjediste["ulica"] as? String ?? ""
                let kucniBroj: String
                if let kbInt = sjediste["kucni_broj"] as? Int {
                    kucniBroj = String(kbInt)
                } else {
                    kucniBroj = sjediste["kucni_broj"] as? String ?? ""
                }
                adresa = [ulica, kucniBroj].filter { !$0.isEmpty }.joined(separator: " ")
                mjesto = sjediste["naziv_naselja"] as? String
                    ?? sjediste["naselje"] as? String
                    ?? ""
                if let zipInt = sjediste["postanski_broj"] as? Int {
                    zip = String(zipInt)
                } else {
                    zip = sjediste["postanski_broj"] as? String ?? ""
                }
            } else {
                // Flat fallback
                let ulica = item["ulica"] as? String ?? ""
                let kucniBroj: String
                if let kbInt = item["kucni_broj"] as? Int {
                    kucniBroj = String(kbInt)
                } else {
                    kucniBroj = item["kucni_broj"] as? String ?? ""
                }
                adresa = [ulica, kucniBroj].filter { !$0.isEmpty }.joined(separator: " ")
                mjesto = item["naziv_naselja"] as? String ?? ""
                if let zipInt = item["postanski_broj"] as? Int {
                    zip = String(zipInt)
                } else {
                    zip = item["postanski_broj"] as? String ?? ""
                }
            }
            
            return SudregSubject(
                mbs: resolvedMbs,
                oib: oib,
                naziv: naziv,
                adresa: adresa,
                mjesto: mjesto,
                postanskiBroj: zip
            )
        } catch {
            print("[Sudreg] Details parse error: \(error.localizedDescription)")
            return nil
        }
    }
}
