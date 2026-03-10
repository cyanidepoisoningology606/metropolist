import CoreLocation
import MapKit

struct StationHeatPoint {
    nonisolated let mapPoint: MKMapPoint
    nonisolated let weight: Double
}

enum VisitFrequencyCalculator {
    static func compute(
        travels: [Travel],
        completedStops: [CompletedStop],
        coordinates: [String: CLLocationCoordinate2D]
    ) -> [StationHeatPoint] {
        var counts: [String: Int] = [:]

        for travel in travels {
            counts[travel.fromStationSourceID, default: 0] += 1
            counts[travel.toStationSourceID, default: 0] += 1
        }

        for stop in completedStops {
            counts[stop.stationSourceID, default: 0] += 1
        }

        guard let maxCount = counts.values.max(), maxCount > 0 else { return [] }

        let logMax = log(Double(maxCount) + 1)

        return counts.compactMap { stationID, count in
            guard let coord = coordinates[stationID] else { return nil }
            let normalized = log(Double(count) + 1) / logMax
            return StationHeatPoint(
                mapPoint: MKMapPoint(coord),
                weight: normalized
            )
        }
    }
}
