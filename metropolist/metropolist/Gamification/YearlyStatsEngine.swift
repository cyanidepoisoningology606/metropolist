import SwiftUI

// MARK: - Yearly Snapshot

struct YearlySnapshot: Equatable {
    let year: Int
    let totalTravels: Int
    let totalDiscoveries: [String]
    let totalNewLines: [String]
    let totalActiveDays: Int
    let bestStreak: Int
    let totalBadgeTierUps: [BadgeTierUp]
    let modeBreakdown: [TransitMode: Int]
    let topLine: MonthlySnapshot.TopLine?
    let bestMonth: DateComponents
    let monthRankings: [(DateComponents, Int)]
    let busiestDay: (Date, Int)
    let longestStreak: (start: Date, length: Int)
    let mostLinesInADay: (Date, Int)
    let mostStationsInADay: (Date, Int)

    static func == (lhs: YearlySnapshot, rhs: YearlySnapshot) -> Bool {
        lhs.year == rhs.year &&
            lhs.totalTravels == rhs.totalTravels &&
            lhs.totalDiscoveries == rhs.totalDiscoveries &&
            lhs.totalNewLines == rhs.totalNewLines &&
            lhs.totalActiveDays == rhs.totalActiveDays &&
            lhs.bestStreak == rhs.bestStreak &&
            lhs.totalBadgeTierUps == rhs.totalBadgeTierUps &&
            lhs.topLine == rhs.topLine &&
            lhs.bestMonth == rhs.bestMonth &&
            lhs.mostLinesInADay.1 == rhs.mostLinesInADay.1 &&
            lhs.mostStationsInADay.1 == rhs.mostStationsInADay.1
    }
}

// MARK: - Engine

enum YearlyStatsEngine {
    static func buildAllSnapshots(
        monthlySnapshots: [MonthlySnapshot],
        travels: [TravelRecord],
        completedStops: [CompletedStopRecord]
    ) -> [YearlySnapshot] {
        let cal = Calendar.current

        let byYear = Dictionary(grouping: monthlySnapshots) { $0.month.year ?? 0 }
        let travelsByYear = Dictionary(grouping: travels) { cal.component(.year, from: $0.createdAt) }
        let stopsByYear = Dictionary(grouping: completedStops) { cal.component(.year, from: $0.completedAt) }

        return byYear.keys.sorted().compactMap { year -> YearlySnapshot? in
            guard let months = byYear[year], !months.isEmpty else { return nil }

            let yearTravels = travelsByYear[year] ?? []

            let totalTravels = months.reduce(0) { $0 + $1.travelCount }
            let totalDiscoveries = Array(Set(months.flatMap(\.uniqueStationsDiscovered)))
            let totalNewLines = Array(Set(months.flatMap(\.linesStarted)))
            let totalBadgeTierUps = months.flatMap(\.badgeTierUps)

            // Mode breakdown: sum across months
            var modeBreakdown: [TransitMode: Int] = [:]
            for month in months {
                for (mode, count) in month.modeBreakdown {
                    modeBreakdown[mode, default: 0] += count
                }
            }

            // Top line across the year (recompute from raw travels)
            let topLine = computeTopLine(travels: yearTravels)

            // Active days: unique days across all months
            let totalActiveDays = computeActiveDays(travels: yearTravels, calendar: cal)

            // Best streak across month boundaries
            let streakResult = computeLongestStreak(travels: yearTravels, calendar: cal)
            let bestStreak = streakResult.length

            // Best month
            let sortedMonths = months.sorted { $0.travelCount > $1.travelCount }
            let bestMonth = sortedMonths.first?.month ?? DateComponents(year: year, month: 1)
            let monthRankings = sortedMonths.map { ($0.month, $0.travelCount) }

            // Busiest day
            let busiestDay = computeBusiestDay(travels: yearTravels, calendar: cal)

            // Most lines in a day
            let mostLinesInADay = computeMostLinesInADay(travels: yearTravels, calendar: cal)

            // Most stations in a day
            let yearStops = stopsByYear[year] ?? []
            let mostStationsInADay = computeMostStationsInADay(completedStops: yearStops, calendar: cal)

            return YearlySnapshot(
                year: year,
                totalTravels: totalTravels,
                totalDiscoveries: totalDiscoveries,
                totalNewLines: totalNewLines,
                totalActiveDays: totalActiveDays,
                bestStreak: bestStreak,
                totalBadgeTierUps: totalBadgeTierUps,
                modeBreakdown: modeBreakdown,
                topLine: topLine,
                bestMonth: bestMonth,
                monthRankings: monthRankings,
                busiestDay: busiestDay,
                longestStreak: streakResult,
                mostLinesInADay: mostLinesInADay,
                mostStationsInADay: mostStationsInADay
            )
        }
    }

    // MARK: - Private Helpers

    private static func computeTopLine(travels: [TravelRecord]) -> MonthlySnapshot.TopLine? {
        guard !travels.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for travel in travels {
            counts[travel.lineSourceID, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return MonthlySnapshot.TopLine(sourceID: top.key, count: top.value)
    }

    private static func computeActiveDays(travels: [TravelRecord], calendar: Calendar) -> Int {
        var days: Set<Date> = []
        for travel in travels {
            days.insert(calendar.startOfDay(for: travel.createdAt))
        }
        return days.count
    }

    private static func computeLongestStreak(
        travels: [TravelRecord],
        calendar: Calendar
    ) -> (start: Date, length: Int) {
        guard !travels.isEmpty else { return (.now, 0) }

        var uniqueDays: Set<Date> = []
        for travel in travels {
            uniqueDays.insert(calendar.startOfDay(for: travel.createdAt))
        }

        let sortedDays = uniqueDays.sorted()
        guard !sortedDays.isEmpty else { return (.now, 0) }

        var bestLength = 1
        var bestStart = sortedDays[0]
        var currentLength = 1
        var currentStart = sortedDays[0]

        for index in 1 ..< sortedDays.count {
            let diff = calendar.dateComponents([.day], from: sortedDays[index - 1], to: sortedDays[index]).day ?? 0
            if diff == 1 {
                currentLength += 1
                if currentLength > bestLength {
                    bestLength = currentLength
                    bestStart = currentStart
                }
            } else {
                currentLength = 1
                currentStart = sortedDays[index]
            }
        }

        return (start: bestStart, length: bestLength)
    }

    private static func computeBusiestDay(
        travels: [TravelRecord],
        calendar: Calendar
    ) -> (Date, Int) {
        guard !travels.isEmpty else { return (.now, 0) }
        var countsByDay: [Date: Int] = [:]
        for travel in travels {
            let day = calendar.startOfDay(for: travel.createdAt)
            countsByDay[day, default: 0] += 1
        }
        let busiest = countsByDay.max(by: { $0.value < $1.value })
        return (busiest?.key ?? .now, busiest?.value ?? 0)
    }

    private static func computeMostLinesInADay(
        travels: [TravelRecord],
        calendar: Calendar
    ) -> (Date, Int) {
        guard !travels.isEmpty else { return (.now, 0) }
        var linesByDay: [Date: Set<String>] = [:]
        for travel in travels {
            let day = calendar.startOfDay(for: travel.createdAt)
            linesByDay[day, default: []].insert(travel.lineSourceID)
        }
        let best = linesByDay.max(by: { $0.value.count < $1.value.count })
        return (best?.key ?? .now, best?.value.count ?? 0)
    }

    private static func computeMostStationsInADay(
        completedStops: [CompletedStopRecord],
        calendar: Calendar
    ) -> (Date, Int) {
        guard !completedStops.isEmpty else { return (.now, 0) }
        var stationsByDay: [Date: Set<String>] = [:]
        for stop in completedStops {
            let day = calendar.startOfDay(for: stop.completedAt)
            stationsByDay[day, default: []].insert(stop.stationSourceID)
        }
        let best = stationsByDay.max(by: { $0.value.count < $1.value.count })
        return (best?.key ?? .now, best?.value.count ?? 0)
    }
}
