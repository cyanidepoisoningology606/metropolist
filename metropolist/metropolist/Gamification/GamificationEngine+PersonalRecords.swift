import Foundation

extension GamificationEngine {
    static func computePersonalRecords(
        from input: GamificationInput,
        travelsByDay: [Date: [TravelRecord]]
    ) -> PersonalRecords {
        PersonalRecords(
            mostTravelsInDay: computeMostTravelsInDay(travelsByDay: travelsByDay),
            mostDiscoveriesInDay: computeMostDiscoveriesInDay(stops: input.completedStops),
            mostModesInDay: computeMostModesInDay(
                travelsByDay: travelsByDay,
                lineMetadata: input.lineMetadata
            ),
            mostDistanceInDay: computeMostDistanceInDay(travelsByDay: travelsByDay)
        )
    }

    // MARK: - Most Travels in a Single Day

    private static func computeMostTravelsInDay(travelsByDay: [Date: [TravelRecord]]) -> DayCountRecord? {
        guard !travelsByDay.isEmpty else { return nil }

        guard let best = travelsByDay.max(by: { $0.value.count < $1.value.count }),
              best.value.count > 1
        else {
            return nil
        }
        return DayCountRecord(count: best.value.count, date: best.key)
    }

    // MARK: - Most Stations Discovered in a Single Day

    private static func computeMostDiscoveriesInDay(stops: [CompletedStopRecord]) -> DayCountRecord? {
        guard !stops.isEmpty else { return nil }
        let cal = Calendar.current
        var stationsByDay: [Date: Set<String>] = [:]

        for stop in stops {
            let day = cal.startOfDay(for: stop.completedAt)
            stationsByDay[day, default: []].insert(stop.stationSourceID)
        }

        guard let best = stationsByDay.max(by: { $0.value.count < $1.value.count }),
              best.value.count > 1
        else {
            return nil
        }
        return DayCountRecord(count: best.value.count, date: best.key)
    }

    // MARK: - Most Modes Used in a Single Day

    private static func computeMostModesInDay(
        travelsByDay: [Date: [TravelRecord]],
        lineMetadata: [String: LineMetadata]
    ) -> MostModesRecord? {
        guard !travelsByDay.isEmpty else { return nil }
        var modesByDay: [Date: Set<TransitMode>] = [:]

        for (day, travels) in travelsByDay {
            for travel in travels {
                guard let meta = lineMetadata[travel.lineSourceID] else { continue }
                modesByDay[day, default: []].insert(meta.mode)
            }
        }

        guard let best = modesByDay.max(by: { $0.value.count < $1.value.count }),
              best.value.count > 1
        else {
            return nil
        }
        return MostModesRecord(
            count: best.value.count,
            date: best.key
        )
    }

    // MARK: - Most Distance in a Single Day

    private static func computeMostDistanceInDay(travelsByDay: [Date: [TravelRecord]]) -> DayDistanceRecord? {
        guard !travelsByDay.isEmpty else { return nil }
        var distanceByDay: [Date: Double] = [:]

        for (day, travels) in travelsByDay {
            for travel in travels {
                guard let dist = travel.distance else { continue }
                distanceByDay[day, default: 0] += dist
            }
        }

        guard let best = distanceByDay.max(by: { $0.value < $1.value }),
              best.value > 0
        else {
            return nil
        }
        return DayDistanceRecord(distance: best.value, date: best.key)
    }
}
