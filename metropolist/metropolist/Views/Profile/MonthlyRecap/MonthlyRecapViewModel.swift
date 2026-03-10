import SwiftUI

struct ResolvedLine {
    let shortName: String
    let color: Color
    let travelCount: Int
}

struct ResolvedStation: Identifiable {
    let id: String
    let name: String
}

struct ResolvedNewLine: Identifiable {
    let sourceID: String
    let shortName: String
    let color: Color
    let textColor: Color

    var id: String {
        sourceID
    }
}

struct ResolvedDiscoveries {
    let newStations: [ResolvedStation]
    let newLines: [ResolvedNewLine]
}

struct ResolvedBadgeUpgrade {
    let lineSourceID: String
    let shortName: String
    let lineColor: Color
    let lineTextColor: Color
    let newTier: BadgeTier
}

@MainActor
@Observable
final class MonthlyRecapViewModel {
    var isLoading = true
    var isEmpty = false
    var error: Error?

    var context: MonthContext?
    var accentColor: Color = .metroSignature
    var dominantMode: TransitMode?
    var formattedMonth = ""
    var resolvedTopLine: ResolvedLine?
    var resolvedDiscoveries = ResolvedDiscoveries(newStations: [], newLines: [])
    var resolvedBadgeUpgrades: [ResolvedBadgeUpgrade] = []
    var totalDistance: Double = 0

    private let month: DateComponents
    private let dataStore: DataStore

    init(month: DateComponents, dataStore: DataStore) {
        self.month = month
        self.dataStore = dataStore
        formattedMonth = MonthFormatting.fullMonth(month)
    }

    func load() async {
        do {
            let travels = try dataStore.userService.allTravels()
            let completedStops = try dataStore.userService.allCompletedStops()
            let metaMap = try dataStore.allLineMetadata()
            let stationMeta = try dataStore.allStationMetadata()

            let travelRecords = travels.map {
                TravelRecord(
                    lineSourceID: $0.lineSourceID,
                    createdAt: $0.createdAt,
                    fromStationSourceID: $0.fromStationSourceID,
                    toStationSourceID: $0.toStationSourceID
                )
            }
            let stopRecords = completedStops.map {
                CompletedStopRecord(
                    lineSourceID: $0.lineSourceID,
                    stationSourceID: $0.stationSourceID,
                    completedAt: $0.completedAt
                )
            }

            let allSnapshots = MonthlyStatsEngine.buildAllSnapshots(
                travels: travelRecords,
                completedStops: stopRecords,
                lineMetadata: metaMap
            )

            guard let ctx = MonthlyStatsEngine.buildContext(for: month, allSnapshots: allSnapshots) else {
                isEmpty = true
                isLoading = false
                return
            }

            context = ctx
            let snapshot = ctx.current

            let cal = Calendar.current
            let monthTravels = travels.filter {
                cal.dateComponents([.year, .month], from: $0.createdAt) == month
            }
            totalDistance = (try? DistanceCalculator.totalDistance(
                for: monthTravels,
                transitService: dataStore.transitService
            )) ?? 0

            // Resolve top line
            if let topLine = snapshot.topLine, let meta = metaMap[topLine.sourceID] {
                resolvedTopLine = ResolvedLine(
                    shortName: meta.shortName,
                    color: Color(hex: meta.color),
                    travelCount: topLine.count
                )
            }

            // Accent color from top line, falling back to dominant mode
            dominantMode = snapshot.modeBreakdown.max(by: { $0.value < $1.value })?.key
            accentColor = resolvedTopLine?.color ?? dominantMode?.tintColor ?? .metroSignature

            // Resolve discoveries
            let newStations: [ResolvedStation] = snapshot.uniqueStationsDiscovered.map { stationID in
                let name = stationMeta[stationID]?.name
                    ?? String(localized: "Unknown station", comment: "Fallback name for unresolved station")
                return ResolvedStation(id: stationID, name: name)
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

            let newLines: [ResolvedNewLine] = snapshot.linesStarted.compactMap { lineID in
                guard let meta = metaMap[lineID] else { return nil }
                return ResolvedNewLine(
                    sourceID: lineID,
                    shortName: meta.shortName,
                    color: Color(hex: meta.color),
                    textColor: Color(hex: meta.textColor)
                )
            }.sorted { $0.shortName.localizedStandardCompare($1.shortName) == .orderedAscending }

            resolvedDiscoveries = ResolvedDiscoveries(newStations: newStations, newLines: newLines)

            // Resolve badge upgrades
            resolvedBadgeUpgrades = snapshot.badgeTierUps.compactMap { tierUp in
                guard let meta = metaMap[tierUp.lineSourceID] else { return nil }
                return ResolvedBadgeUpgrade(
                    lineSourceID: tierUp.lineSourceID,
                    shortName: meta.shortName,
                    lineColor: Color(hex: meta.color),
                    lineTextColor: Color(hex: meta.textColor),
                    newTier: tierUp.newTier
                )
            }

        } catch {
            self.error = error
        }
        isLoading = false
    }
}
