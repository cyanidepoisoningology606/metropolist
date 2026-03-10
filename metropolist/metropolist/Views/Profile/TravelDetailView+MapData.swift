import MapKit
import TransitModels

extension TravelDetailView {
    struct MapData {
        let segment: [CLLocationCoordinate2D]
        let annotations: [LineRouteMapView.StationAnnotation]
    }

    func buildMapData(
        travel: Travel,
        journeyStops: [TransitLineStop],
        stationNames: [String: String],
        transitService: TransitDataService
    ) throws -> MapData {
        let allStations = try transitService.stations(bySourceIDs: Array(stationNames.keys))
        let stationsById = Dictionary(uniqueKeysWithValues: allStations.map { ($0.sourceID, $0) })

        let stopIDs = journeyStops.isEmpty
            ? [travel.fromStationSourceID, travel.toStationSourceID]
            : journeyStops.map(\.stationSourceID)

        var coords: [CLLocationCoordinate2D] = []
        var annotations: [LineRouteMapView.StationAnnotation] = []
        for id in stopIDs {
            guard let station = stationsById[id] else { continue }
            let coord = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
            coords.append(coord)
            let isEndpoint = id == travel.fromStationSourceID || id == travel.toStationSourceID
            annotations.append(LineRouteMapView.StationAnnotation(
                id: id,
                coordinate: coord,
                isTerminus: isEndpoint
            ))
        }
        return MapData(segment: coords, annotations: annotations)
    }
}
