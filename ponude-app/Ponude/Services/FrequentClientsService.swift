import Foundation

/// A predefined public institution entry loaded from the bundled JSON.
struct FrequentClient: Decodable, Identifiable {
    var id: String { oib }
    let name: String
    let oib: String
    let address: String
    let city: String
    let zipCode: String
    let category: String
}

/// Service for searching bundled public institutions (tourist boards, cities,
/// counties, etc.) that are NOT registered in Sudreg.
///
/// These entities are stored in `frequent_clients.json` inside the app bundle
/// and can be searched by name or OIB for instant autofill without any API call.
final class FrequentClientsService {
    
    /// Singleton — the JSON is small enough to keep in memory
    static let shared = FrequentClientsService()
    
    private var clients: [FrequentClient] = []
    
    private init() {
        loadClients()
    }
    
    // MARK: - Public API
    
    /// Search predefined clients by name or OIB.
    /// Returns all matches (case-insensitive partial match on name, prefix match on OIB).
    func search(query: String) -> [FrequentClient] {
        guard !query.isEmpty else { return [] }
        
        // Split query into individual words for multi-word matching
        let words = query.lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        
        guard !words.isEmpty else { return [] }
        
        return clients.filter { client in
            // OIB prefix match
            if client.oib.hasPrefix(query) { return true }
            
            // All words must appear somewhere in the name (diacritic-insensitive)
            let name = client.name
            return words.allSatisfy { word in
                name.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }
    
    /// Return all predefined clients (e.g. for browsing)
    var allClients: [FrequentClient] {
        clients
    }
    
    // MARK: - Loading
    
    private func loadClients() {
        // Try loading from the app bundle
        guard let url = Bundle.main.url(forResource: "frequent_clients", withExtension: "json") else {
            print("[FrequentClients] frequent_clients.json not found in bundle")
            // Fallback: try loading from the Resources directory relative to executable
            loadFromFallbackPath()
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            clients = try JSONDecoder().decode([FrequentClient].self, from: data)
            print("[FrequentClients] Loaded \(clients.count) predefined clients from bundle")
        } catch {
            print("[FrequentClients] Failed to decode: \(error.localizedDescription)")
        }
    }
    
    /// Fallback for development builds where bundle resources might not be in the expected location
    private func loadFromFallbackPath() {
        let executableURL = Bundle.main.executableURL?.deletingLastPathComponent()
        let possiblePaths = [
            executableURL?.appendingPathComponent("Resources/frequent_clients.json"),
            executableURL?.deletingLastPathComponent().appendingPathComponent("Resources/frequent_clients.json"),
        ].compactMap { $0 }
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                do {
                    let data = try Data(contentsOf: path)
                    clients = try JSONDecoder().decode([FrequentClient].self, from: data)
                    print("[FrequentClients] Loaded \(clients.count) predefined clients from: \(path.path)")
                    return
                } catch {
                    print("[FrequentClients] Failed to decode from \(path.path): \(error.localizedDescription)")
                }
            }
        }
        
        print("[FrequentClients] No fallback path found — predefined clients unavailable")
    }
}
