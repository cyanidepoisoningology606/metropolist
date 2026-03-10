import Foundation
import SwiftData

@Model
public final class TransitLine {
    @Attribute(.unique) public var sourceID: String
    public var shortName: String
    public var longName: String
    public var mode: String
    public var submode: String?
    public var color: String
    public var textColor: String
    public var operatorName: String
    public var networkName: String?
    public var status: String
    public var isAccessible: Bool
    public var groupID: String?
    public var groupName: String?

    public init(
        sourceID: String, shortName: String, longName: String,
        mode: String, submode: String?, color: String, textColor: String,
        operatorName: String, networkName: String?, status: String,
        isAccessible: Bool, groupID: String?, groupName: String?
    ) {
        self.sourceID = sourceID
        self.shortName = shortName
        self.longName = longName
        self.mode = mode
        self.submode = submode
        self.color = color
        self.textColor = textColor
        self.operatorName = operatorName
        self.networkName = networkName
        self.status = status
        self.isAccessible = isAccessible
        self.groupID = groupID
        self.groupName = groupName
    }
}

@Model
public final class TransitStation {
    @Attribute(.unique) public var sourceID: String
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var fareZone: String?
    public var town: String?
    public var postalCode: String?
    public var isAccessible: Bool
    public var hasAudibleSignals: Bool
    public var hasVisualSigns: Bool

    public init(
        sourceID: String, name: String, latitude: Double, longitude: Double,
        fareZone: String?, town: String?, postalCode: String?,
        isAccessible: Bool, hasAudibleSignals: Bool, hasVisualSigns: Bool
    ) {
        self.sourceID = sourceID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.fareZone = fareZone
        self.town = town
        self.postalCode = postalCode
        self.isAccessible = isAccessible
        self.hasAudibleSignals = hasAudibleSignals
        self.hasVisualSigns = hasVisualSigns
    }
}

@Model
public final class TransitRouteVariant {
    @Attribute(.unique) public var sourceID: String
    public var lineSourceID: String
    public var direction: Int
    public var headsign: String
    public var stationCount: Int

    public init(
        sourceID: String, lineSourceID: String,
        direction: Int, headsign: String, stationCount: Int
    ) {
        self.sourceID = sourceID
        self.lineSourceID = lineSourceID
        self.direction = direction
        self.headsign = headsign
        self.stationCount = stationCount
    }
}

@Model
public final class TransitLineStop {
    public var lineSourceID: String
    public var stationSourceID: String
    public var routeVariantSourceID: String
    public var order: Int
    public var isTerminus: Bool

    public init(
        lineSourceID: String, stationSourceID: String,
        routeVariantSourceID: String, order: Int, isTerminus: Bool
    ) {
        self.lineSourceID = lineSourceID
        self.stationSourceID = stationSourceID
        self.routeVariantSourceID = routeVariantSourceID
        self.order = order
        self.isTerminus = isTerminus
    }
}

@Model
public final class TransitTransfer {
    public var fromStationSourceID: String
    public var toStationSourceID: String
    public var minTransferTime: Int

    // periphery:ignore - Used by StoreBuilder target
    public init(
        fromStationSourceID: String, toStationSourceID: String,
        minTransferTime: Int
    ) {
        self.fromStationSourceID = fromStationSourceID
        self.toStationSourceID = toStationSourceID
        self.minTransferTime = minTransferTime
    }
}

@Model
public final class TransitMetadata {
    public var key: String
    public var value: String

    // periphery:ignore - Used by StoreBuilder target
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

