import Foundation

enum GamificationEngine {
    // MARK: - XP Constants

    static let xpPerTravel = 5
    static let xpPerUniqueStop = 20
    static let xpPerFirstLineBus = 25
    static let xpPerFirstLineOther = 50
    static let xpBaseLineCompletion = 50
    static let xpPerLineCompletionStop = 5

    // MARK: - Main Entry Point

    static func computeSnapshot(from input: GamificationInput) -> GamificationSnapshot {
        let completedByLine = Dictionary(grouping: input.completedStops, by: \.lineSourceID)
        let linesByMode = Dictionary(grouping: input.lineMetadata.values, by: \.mode)

        let (lineProgress, completedLineIDs) = computeLineProgress(
            lineMetadata: input.lineMetadata,
            completedByLine: completedByLine
        )

        let lineBadges = lineProgress.mapValues(\.badge)

        let modeBadges = computeModeBadges(
            linesByMode: linesByMode,
            completedByLine: completedByLine
        )

        let cal = Calendar.current
        let travelsByDay: [Date: [TravelRecord]] = {
            var map: [Date: [TravelRecord]] = [:]
            for travel in input.travels {
                let day = cal.startOfDay(for: travel.createdAt)
                map[day, default: []].append(travel)
            }
            return map
        }()

        let uniqueTravelDays = travelsByDay.keys.sorted()

        let uniqueStations = Set(input.completedStops.map(\.stationSourceID))

        let firstLineXP = computeFirstLineXP(
            travels: input.travels,
            lineMetadata: input.lineMetadata
        )

        let lineCompletionXP = computeLineCompletionXP(
            completedLineIDs: completedLineIDs,
            lineMetadata: input.lineMetadata
        )

        let streakXP = computeStreakXP(uniqueDays: uniqueTravelDays)

        let stats = computeStats(
            input: input,
            uniqueStationCount: uniqueStations.count,
            completedLineIDs: completedLineIDs,
            uniqueTravelDays: uniqueTravelDays
        )

        let achievementCtx = buildAchievementContext(
            input: input,
            linesByMode: linesByMode,
            completedByLine: completedByLine,
            uniqueTravelDays: uniqueTravelDays,
            travelsByDay: travelsByDay
        )

        let achievements = AchievementDefinitions.all.map { def in
            let date = def.evaluate(achievementCtx)
            return AchievementState(
                id: def.id,
                definition: def,
                isUnlocked: date != nil,
                unlockedAt: date
            )
        }

        let achievementXP = computeAchievementXP(achievements: achievements)

        let xpBreakdown = XPBreakdown(
            travelXP: input.travels.count * xpPerTravel,
            stopXP: uniqueStations.count * xpPerUniqueStop,
            lineCompletionXP: lineCompletionXP,
            firstLineXP: firstLineXP,
            achievementXP: achievementXP,
            streakXP: streakXP
        )

        let extendedStats = computeExtendedStats(from: input, travelsByDay: travelsByDay)

        let totalXP = xpBreakdown.total
        let level = LevelDefinitions.level(forXP: totalXP)
        let xpInCurrent = LevelDefinitions.xpInCurrentLevel(totalXP: totalXP)
        let xpToNext = LevelDefinitions.xpToNextLevel(totalXP: totalXP)

        return GamificationSnapshot(
            totalXP: totalXP,
            level: level,
            xpInCurrentLevel: xpInCurrent,
            xpToNextLevel: xpToNext,
            lineBadges: lineBadges,
            modeBadges: modeBadges,
            achievements: achievements,
            stats: stats,
            lineProgress: lineProgress,
            xpBreakdown: xpBreakdown,
            extendedStats: extendedStats
        )
    }

    // MARK: - Line Progress

    private static func computeLineProgress(
        lineMetadata: [String: LineMetadata],
        completedByLine: [String: [CompletedStopRecord]]
    ) -> ([String: LineProgress], Set<String>) {
        var lineProgress: [String: LineProgress] = [:]
        var completedLineIDs: Set<String> = []
        for (sourceID, meta) in lineMetadata {
            let completed = completedByLine[sourceID]?.count ?? 0
            let fraction = meta.totalStations > 0 ? Double(completed) / Double(meta.totalStations) : 0
            let badge = BadgeComputation.completionTier(completed: completed, total: meta.totalStations)
            lineProgress[sourceID] = LineProgress(
                completedStops: completed,
                totalStops: meta.totalStations,
                badge: badge,
                fraction: fraction
            )
            if completed >= meta.totalStations, meta.totalStations > 0 {
                completedLineIDs.insert(sourceID)
            }
        }
        return (lineProgress, completedLineIDs)
    }

    // MARK: - Mode Badges

    private static func computeModeBadges(
        linesByMode: [TransitMode: [LineMetadata]],
        completedByLine: [String: [CompletedStopRecord]]
    ) -> [TransitMode: BadgeTier] {
        var modeBadges: [TransitMode: BadgeTier] = [:]
        for (mode, lines) in linesByMode {
            var totalStops = 0
            var completedStops = 0
            for line in lines {
                totalStops += line.totalStations
                completedStops += completedByLine[line.sourceID]?.count ?? 0
            }
            modeBadges[mode] = BadgeComputation.completionTier(completed: completedStops, total: totalStops)
        }
        return modeBadges
    }

    // MARK: - XP Computation

    private static func computeFirstLineXP(
        travels: [TravelRecord],
        lineMetadata: [String: LineMetadata]
    ) -> Int {
        var seenLines: Set<String> = []
        var total = 0
        for travel in travels {
            guard seenLines.insert(travel.lineSourceID).inserted else { continue }
            let isBus = lineMetadata[travel.lineSourceID]?.mode == .bus
            total += isBus ? xpPerFirstLineBus : xpPerFirstLineOther
        }
        return total
    }

    private static func computeLineCompletionXP(
        completedLineIDs: Set<String>,
        lineMetadata: [String: LineMetadata]
    ) -> Int {
        var total = 0
        for lineID in completedLineIDs {
            let totalStations = lineMetadata[lineID]?.totalStations ?? 0
            total += xpBaseLineCompletion + (totalStations * xpPerLineCompletionStop)
        }
        return total
    }

    private static func computeAchievementXP(achievements: [AchievementState]) -> Int {
        achievements
            .filter(\.isUnlocked)
            .reduce(0) { $0 + $1.definition.xpReward }
    }

    // MARK: - Achievement Context

    private static func buildAchievementContext(
        input: GamificationInput,
        linesByMode: [TransitMode: [LineMetadata]],
        completedByLine: [String: [CompletedStopRecord]],
        uniqueTravelDays: [Date],
        travelsByDay: [Date: [TravelRecord]]
    ) -> AchievementContext {
        let sortedStops = input.completedStops.sorted { $0.completedAt < $1.completedAt }
        let sortedTravels = input.travels.sorted { $0.createdAt < $1.createdAt }
        let sortedTravelDates = sortedTravels.map(\.createdAt)
        let totalNetworkStops = input.lineMetadata.values.reduce(0) { $0 + $1.totalStations }
        let modesUsed: Set<TransitMode> = Set(input.travels.compactMap { travel in
            input.lineMetadata[travel.lineSourceID]?.mode
        })
        let uniqueDates = computeUniqueDates(
            sortedStops: sortedStops,
            travels: sortedTravels
        )
        let lineCompletionDates = computeLineCompletionDates(
            lineMetadata: input.lineMetadata,
            completedByLine: completedByLine
        )
        let modeCompletionDates = computeModeCompletionDates(
            linesByMode: linesByMode,
            lineCompletionDates: lineCompletionDates
        )
        let travelMilestones = computeTravelMilestones(
            sortedTravels: sortedTravels,
            lineMetadata: input.lineMetadata,
            travelsByDay: travelsByDay
        )
        let streakMilestoneDates = computeStreakMilestones(uniqueDays: uniqueTravelDays, targets: [7, 30])
        let networkHalfDate = computeNetworkHalfDate(
            sortedStops: sortedStops,
            totalNetworkStops: totalNetworkStops
        )
        let linesByModeIDs: [TransitMode: Set<String>] = linesByMode.mapValues { lines in
            Set(lines.map(\.sourceID))
        }

        let stationAchievements = computeStationAchievements(
            input: input,
            sortedStops: sortedStops,
            sortedTravels: sortedTravels
        )

        let rerCCompletionDate: Date? = {
            guard let rerCID = input.lineMetadata.first(where: { $0.value.mode == .rer && $0.value.shortName == "C" })?.key else {
                return nil
            }
            return lineCompletionDates[rerCID]
        }()

        return AchievementContext(
            totalTravels: input.travels.count,
            modesUsed: modesUsed,
            linesByMode: linesByModeIDs,
            travelDates: input.travels.map(\.createdAt),
            firstTravelDate: sortedTravels.first?.createdAt,
            evaluationDate: Date(),
            nthUniqueStationDates: uniqueDates.stationDates,
            nthUniqueLineDates: uniqueDates.lineDates,
            sortedTravelDates: sortedTravelDates,
            sortedLineCompletionDates: lineCompletionDates.values.sorted(),
            modeCompletionDates: modeCompletionDates,
            modeFirstUsedDates: travelMilestones.modeFirstUsedDates,
            firstMultiModeDayDate: travelMilestones.firstMultiModeDayDate,
            firstNoctilienDate: travelMilestones.firstNoctilienDate,
            streakMilestoneDates: streakMilestoneDates,
            networkHalfDate: networkHalfDate,
            firstBirHakeimLine6Date: stationAchievements.firstBirHakeimLine6Date,
            allDepartmentsCoveredDate: stationAchievements.allDepartmentsCoveredDate,
            firstOperaNightTravelDate: stationAchievements.firstOperaNightTravelDate,
            firstLine13RushHourDate: stationAchievements.firstLine13RushHourDate,
            nthUniqueBusLineDates: stationAchievements.nthUniqueBusLineDates,
            rerCCompletionDate: rerCCompletionDate,
            firstChateauRougeDate: stationAchievements.firstChateauRougeDate,
            firstSameRouteTenTimesDate: stationAchievements.firstSameRouteTenTimesDate,
            firstT3aAndT3bDate: stationAchievements.firstT3aAndT3bDate
        )
    }

    private static func computeUniqueDates(
        sortedStops: [CompletedStopRecord],
        travels: [TravelRecord]
    ) -> (stationDates: [Date], lineDates: [Date]) {
        var seenStations: Set<String> = []
        var stationDates: [Date] = []
        for stop in sortedStops where seenStations.insert(stop.stationSourceID).inserted {
            stationDates.append(stop.completedAt)
        }

        var seenLines: Set<String> = []
        var lineDates: [Date] = []
        for travel in travels where seenLines.insert(travel.lineSourceID).inserted {
            lineDates.append(travel.createdAt)
        }

        return (stationDates, lineDates)
    }

    private static func computeLineCompletionDates(
        lineMetadata: [String: LineMetadata],
        completedByLine: [String: [CompletedStopRecord]]
    ) -> [String: Date] {
        var lineCompletionDates: [String: Date] = [:]
        for (sourceID, meta) in lineMetadata {
            guard meta.totalStations > 0 else { continue }
            let stops = (completedByLine[sourceID] ?? []).sorted { $0.completedAt < $1.completedAt }
            var uniqueInLine: Set<String> = []
            for stop in stops {
                uniqueInLine.insert(stop.stationSourceID)
                if uniqueInLine.count >= meta.totalStations {
                    lineCompletionDates[sourceID] = stop.completedAt
                    break
                }
            }
        }
        return lineCompletionDates
    }

    private static func computeModeCompletionDates(
        linesByMode: [TransitMode: [LineMetadata]],
        lineCompletionDates: [String: Date]
    ) -> [TransitMode: Date] {
        var modeCompletionDates: [TransitMode: Date] = [:]
        for (mode, lines) in linesByMode {
            let allIDs = Set(lines.map(\.sourceID))
            guard !allIDs.isEmpty, allIDs.allSatisfy({ lineCompletionDates[$0] != nil }) else { continue }
            modeCompletionDates[mode] = allIDs.compactMap { lineCompletionDates[$0] }.max()
        }
        return modeCompletionDates
    }

    private struct TravelMilestones {
        var modeFirstUsedDates: [TransitMode: Date]
        var firstMultiModeDayDate: Date?
        var firstNoctilienDate: Date?
    }

    private static func computeTravelMilestones(
        sortedTravels: [TravelRecord],
        lineMetadata: [String: LineMetadata],
        travelsByDay: [Date: [TravelRecord]]
    ) -> TravelMilestones {
        var modeFirstUsedDates: [TransitMode: Date] = [:]
        var firstMultiModeDayDate: Date?
        var dayModeTracking: [Date: Set<TransitMode>] = [:]
        var firstNoctilienDate: Date?

        // Build createdAt → day lookup from pre-computed travelsByDay
        var dayForTravel: [Date: Date] = [:]
        for (day, travels) in travelsByDay {
            for travel in travels {
                dayForTravel[travel.createdAt] = day
            }
        }

        for travel in sortedTravels {
            if let mode = lineMetadata[travel.lineSourceID]?.mode {
                if modeFirstUsedDates[mode] == nil {
                    modeFirstUsedDates[mode] = travel.createdAt
                }
                if let day = dayForTravel[travel.createdAt] {
                    dayModeTracking[day, default: []].insert(mode)
                    if (dayModeTracking[day]?.count ?? 0) >= 3, firstMultiModeDayDate == nil {
                        firstMultiModeDayDate = travel.createdAt
                    }
                }
            }
            if firstNoctilienDate == nil {
                if lineMetadata[travel.lineSourceID]?.submode == "nightBus" {
                    firstNoctilienDate = travel.createdAt
                }
            }
        }

        return TravelMilestones(
            modeFirstUsedDates: modeFirstUsedDates,
            firstMultiModeDayDate: firstMultiModeDayDate,
            firstNoctilienDate: firstNoctilienDate
        )
    }
}
