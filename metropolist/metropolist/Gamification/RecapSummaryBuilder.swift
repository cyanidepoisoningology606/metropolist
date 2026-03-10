import SwiftUI

enum RecapSummaryBuilder {
    static func buildSummaries(
        travels: [Travel],
        completedStops: [CompletedStop],
        metaMap: [String: LineMetadata]
    ) -> [RecapSummary] {
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

        guard !allSnapshots.isEmpty else { return [] }

        let yearlySnapshots = YearlyStatsEngine.buildAllSnapshots(
            monthlySnapshots: allSnapshots,
            travels: travelRecords,
            completedStops: stopRecords
        )

        let cal = Calendar.current
        let currentMonth = cal.dateComponents([.year, .month], from: Date())
        let currentYear = cal.component(.year, from: Date())

        let completedSnapshots = allSnapshots.filter { $0.month != currentMonth }
        let completedYearly = yearlySnapshots.filter { $0.year != currentYear }

        let monthlySummaries = buildMonthlySummaries(
            allSnapshots: completedSnapshots,
            metaMap: metaMap
        )

        let yearlySummaries = buildYearlySummaries(
            yearlySnapshots: completedYearly
        )

        return interleave(monthly: monthlySummaries, yearly: yearlySummaries)
    }

    // MARK: - Monthly

    private static func buildMonthlySummaries(
        allSnapshots: [MonthlySnapshot],
        metaMap: [String: LineMetadata]
    ) -> [RecapSummary] {
        allSnapshots.map { snapshot in
            let dominant = snapshot.modeBreakdown.max(by: { $0.value < $1.value })?.key
            let topLineColor = snapshot.topLine
                .flatMap { metaMap[$0.sourceID] }
                .map { Color(hex: $0.color) }
            return RecapSummary(
                kind: .monthly(snapshot.month),
                formattedTitle: MonthFormatting.fullMonth(snapshot.month),
                abbreviatedLabel: MonthFormatting.abbreviatedMonth(snapshot.month),
                travelCount: snapshot.travelCount,
                discoveryCount: snapshot.uniqueStationsDiscovered.count,
                activeDays: snapshot.activeDays,
                dominantMode: dominant,
                topLineColor: topLineColor,
                topModeColors: []
            )
        }
    }

    // MARK: - Yearly

    private static func buildYearlySummaries(
        yearlySnapshots: [YearlySnapshot]
    ) -> [RecapSummary] {
        yearlySnapshots.map { snapshot in
            let topModes = snapshot.modeBreakdown.sorted { $0.value > $1.value }.prefix(3)
            let modeColors = topModes.map(\.key.tintColor)
            let dominant = topModes.first?.key
            let yearStr = String(snapshot.year)
            return RecapSummary(
                kind: .yearly(snapshot.year),
                formattedTitle: String(localized: "\(yearStr) Wrapped", comment: "Yearly recap: title for completed year"),
                abbreviatedLabel: String(snapshot.year),
                travelCount: snapshot.totalTravels,
                discoveryCount: snapshot.totalDiscoveries.count,
                activeDays: snapshot.totalActiveDays,
                dominantMode: dominant,
                topLineColor: nil,
                topModeColors: modeColors
            )
        }
    }

    // MARK: - Interleave

    private static func interleave(
        monthly: [RecapSummary],
        yearly: [RecapSummary]
    ) -> [RecapSummary] {
        let reversedMonthly = Array(monthly.reversed())

        var yearlyByYear: [Int: RecapSummary] = [:]
        for summary in yearly {
            if case let .yearly(year) = summary.kind {
                yearlyByYear[year] = summary
            }
        }

        var result: [RecapSummary] = []
        var insertedYears: Set<Int> = []
        var previousMonthYear: Int?

        for monthlySummary in reversedMonthly {
            let monthYear = monthlySummary.year

            if let prevYear = previousMonthYear, prevYear > monthYear {
                if !insertedYears.contains(monthYear), let yearlySummary = yearlyByYear[monthYear] {
                    result.append(yearlySummary)
                    insertedYears.insert(monthYear)
                }
            }

            result.append(monthlySummary)
            previousMonthYear = monthYear
        }

        for yearSummary in yearly.sorted(by: { $0.year > $1.year }) {
            if case let .yearly(year) = yearSummary.kind, !insertedYears.contains(year) {
                if let firstIndex = result.firstIndex(where: { $0.year <= year }) {
                    result.insert(yearSummary, at: firstIndex)
                } else {
                    result.append(yearSummary)
                }
                insertedYears.insert(year)
            }
        }

        return result
    }
}
