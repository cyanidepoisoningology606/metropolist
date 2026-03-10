import Foundation

struct MetropolistDataDTO: Decodable {
    let dataVersion: Int
    let generatedAt: String
    let lines: [LineDTO]
    let stations: [StationDTO]
    let lineStops: [LineStopDTO]
    let routeVariants: [RouteVariantDTO]
    let transfers: [TransferDTO]
}

struct LineDTO: Decodable {
    let id: String
    let shortName: String
    let longName: String
    let mode: String
    let submode: String?
    let color: String
    let textColor: String
    let operatorName: String
    let networkName: String?
    let status: String
    let isAccessible: Bool
    let groupId: String?
    let groupName: String?
}

struct StationDTO: Decodable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let fareZone: String?
    let town: String?
    let postalCode: String?
    let isAccessible: Bool
    let hasAudibleSignals: Bool
    let hasVisualSigns: Bool
}

struct RouteVariantDTO: Decodable {
    let id: String
    let lineId: String
    let direction: Int
    let headsign: String
    let stationCount: Int
}

struct LineStopDTO: Decodable {
    let lineId: String
    let stationId: String
    let routeVariantId: String
    let order: Int
    let isTerminus: Bool
}

struct TransferDTO: Decodable {
    let fromStationId: String
    let toStationId: String
    let minTransferTime: Int
}
