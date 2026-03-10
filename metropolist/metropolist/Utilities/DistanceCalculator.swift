import CoreLocation
import TransitModels

enum DistanceCalculator {
    /// Computes the geographic distance of a single travel by summing
    /// station-to-station distances along the resolved route.
    /// Returns distance in meters, or `nil` if the route cannot be resolved.
    static func distance(for travel: Travel, transitService: TransitDataService) throws -> Double? {
        let allStops = try transitService.lineStops(forRouteVariantSourceID: travel.routeVariantSourceID)
        guard let fromOrder = allStops.order(of: travel.fromStationSourceID) else { return nil }

        let resolvedToOrder: Int? = if let forward = allStops.order(of: travel.toStationSourceID, after: fromOrder) {
            forward
        } else {
            allStops.order(of: travel.toStationSourceID, before: fromOrder)
        }
        guard let toOrder = resolvedToOrder else { return nil }

        let lower = min(fromOrder, toOrder)
        let upper = max(fromOrder, toOrder)
        let journeyStops = try transitService.intermediateStops(
            routeVariantSourceID: travel.routeVariantSourceID,
            fromOrder: lower,
            toOrder: upper
        )

        let stationIDs = journeyStops.map(\.stationSourceID)
        let stations = try transitService.stations(bySourceIDs: stationIDs)
        let stationsByID = Dictionary(uniqueKeysWithValues: stations.map { ($0.sourceID, $0) })

        let orderedStations = journeyStops.compactMap { stationsByID[$0.stationSourceID] }
        guard orderedStations.count >= 2 else { return nil }

        var total = 0.0
        for index in 0 ..< orderedStations.count - 1 {
            let origin = CLLocation(latitude: orderedStations[index].latitude, longitude: orderedStations[index].longitude)
            let destination = CLLocation(
                latitude: orderedStations[index + 1].latitude,
                longitude: orderedStations[index + 1].longitude
            )
            total += origin.distance(from: destination)
        }
        return total
    }

    /// Sums distances for multiple travels, skipping any that cannot be resolved.
    static func totalDistance(for travels: [Travel], transitService: TransitDataService) throws -> Double {
        var total = 0.0
        for travel in travels {
            if let dist = try distance(for: travel, transitService: transitService) {
                total += dist
            }
        }
        return total
    }

    /// Formats a distance in meters as a human-readable string ("X m" or "X.X km").
    static func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(localized: "\(Int(meters)) m", comment: "Distance: meters")
        } else {
            let kilometers = String(format: "%.1f", meters / 1000)
            return String(localized: "\(kilometers) km", comment: "Distance: kilometers")
        }
    }
}
