import CoreLocation
import Foundation
import TransitModels

// MARK: - Station Loading

extension TravelFlowViewModel {
    // MARK: - Nearby Stations

    func loadNearbyStations() {
        isLoadingNearby = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let userLocation = try await dataStore.locationService.requestLocationAsync()

                let radiusMeters = UserDefaults.standard.integer(forKey: "nearbyRadius")
                let radius = Double(radiusMeters > 0 ? radiusMeters : 500)
                let latDegrees = radius / 111_000.0
                let lonDegrees = latDegrees / cos(userLocation.coordinate.latitude * .pi / 180)

                let stations = try dataStore.transitService.nearbyStations(
                    latitude: userLocation.coordinate.latitude,
                    longitude: userLocation.coordinate.longitude,
                    latRadius: latDegrees,
                    lonRadius: lonDegrees
                )

                // Filter by actual distance, sort, take closest 20
                let sorted = stations
                    .map { station -> (TransitStation, CLLocationDistance) in
                        let stationLoc = CLLocation(latitude: station.latitude, longitude: station.longitude)
                        return (station, userLocation.distance(from: stationLoc))
                    }
                    .filter { $0.1 <= radius }
                    .sorted { $0.1 < $1.1 }
                    .prefix(20)

                // Batch-fetch lines for all top stations (2 queries instead of 40)
                let stationIDs = Set(sorted.map(\.0.sourceID))
                let linesByStation = try dataStore.transitService.connectingLinesByStation(
                    forStationSourceIDs: stationIDs
                )

                let nearby = sorted.map { station, distance in
                    NearbyStation(station: station, distance: distance, lines: linesByStation[station.sourceID] ?? [])
                }

                nearbyStations = nearby
            } catch {
                nearbyStations = []
            }

            isLoadingNearby = false
        }
    }

    func refreshNearbyStations() {
        dataStore.locationService.invalidateCache()
        nearbyStations = []
        loadNearbyStations()
    }

    func searchStations(query: String) -> [TransitStation] {
        guard !query.isEmpty else { return [] }
        return logged { try dataStore.searchStations(query: query) } ?? []
    }

    func linesForStation(_ sourceID: String) -> [TransitLine] {
        logged { try dataStore.transitService.lines(forStationSourceID: sourceID) } ?? []
    }

    func linesForStations(_ sourceIDs: Set<String>) -> [String: [TransitLine]] {
        logged { try dataStore.transitService.connectingLinesByStation(forStationSourceIDs: sourceIDs) } ?? [:]
    }

    // MARK: - Line Prefill

    func loadLineStations() async {
        guard let lineID = prefill?.lineSourceID else { return }
        isLoadingLineStations = true
        await Task.yield()

        do {
            prefillLine = try dataStore.transitService.line(bySourceID: lineID)

            let variants = try dataStore.transitService.routeVariants(forLineSourceID: lineID)
            // Pick the longest variant to get the most complete stop list
            var longestStops: [TransitLineStop] = []
            for variant in variants {
                let stops = try dataStore.transitService.lineStops(forRouteVariantSourceID: variant.sourceID)
                if stops.count > longestStops.count {
                    longestStops = stops
                }
            }

            let orderedStops = longestStops.sorted { $0.order < $1.order }

            // Deduplicate by stationSourceID while preserving order
            var seen = Set<String>()
            var uniqueIDs: [String] = []
            for stop in orderedStops where seen.insert(stop.stationSourceID).inserted {
                uniqueIDs.append(stop.stationSourceID)
            }

            let stations = try dataStore.transitService.stations(bySourceIDs: uniqueIDs)
            let stationMap = Dictionary(uniqueKeysWithValues: stations.map { ($0.sourceID, $0) })

            // Preserve route order
            prefillLineStations = uniqueIDs.compactMap { stationMap[$0] }
        } catch {
            prefillLineStations = []
        }

        isLoadingLineStations = false
    }

    func autoSelectOriginFromPrefill() {
        guard let stationID = prefill?.stationSourceID else { return }
        do {
            if let station = try dataStore.transitService.station(bySourceID: stationID) {
                selectOrigin(station)
            }
        } catch {
            // Station not found — fall through to normal picker
        }
    }
}
