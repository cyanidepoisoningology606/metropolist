import Foundation

/// Caches computed travel distances to avoid redundant SwiftData fetches
/// against the transit database on every `GamificationSnapshot.build()` call.
///
/// The cache is local-only (not synced via iCloud) and keyed by travel ID.
/// It invalidates automatically when the bundled transit database is updated.
struct DistanceCache {
    enum Lookup {
        case hit(Double?)
        case miss
    }

    private var distances: [String: Double] = [:]
    private var unresolved: Set<String> = []
    private var dirty = false

    /// Loads the cache from disk, returning an empty cache if the file
    /// is missing, corrupt, or stale (transit data version mismatch).
    static func load() -> DistanceCache {
        var cache = DistanceCache()
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return cache }
        guard let stored = try? JSONDecoder().decode(StoredData.self, from: data) else { return cache }

        let currentVersion = UserDefaults.standard.string(forKey: "transitStoreModDate") ?? ""
        guard stored.transitVersion == currentVersion else { return cache }

        cache.distances = stored.distances
        cache.unresolved = stored.unresolved
        return cache
    }

    func lookup(travelID: String) -> Lookup {
        if let dist = distances[travelID] {
            return .hit(dist)
        }
        if unresolved.contains(travelID) {
            return .hit(nil)
        }
        return .miss
    }

    mutating func set(distance: Double?, forTravelID id: String) {
        if let distance {
            distances[id] = distance
        } else {
            unresolved.insert(id)
        }
        dirty = true
    }

    func persistIfNeeded() {
        guard dirty else { return }
        let version = UserDefaults.standard.string(forKey: "transitStoreModDate") ?? ""
        let stored = StoredData(
            distances: distances,
            unresolved: unresolved,
            transitVersion: version
        )
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Private

    private static var fileURL: URL? {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("distance-cache.json")
    }

    private struct StoredData: Codable {
        let distances: [String: Double]
        let unresolved: Set<String>
        let transitVersion: String
    }
}
