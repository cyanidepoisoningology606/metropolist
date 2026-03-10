import Foundation
@testable import metropolist
import Testing

@Suite(.tags(.gamification, .stats))
@MainActor
struct TravelsPerMonthTests {
    // MARK: - Empty / Single

    @Test("Empty travels returns empty array")
    func emptyTravels() {
        let input = GamificationInput(
            completedStops: [],
            travels: [],
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input, travelsByDay: TestFixtures.travelsByDay(from: input))
        #expect(stats.travelsPerMonth.isEmpty)
    }

    @Test("Single travel returns one month entry")
    func singleTravel() {
        let input = GamificationInput(
            completedStops: [],
            travels: [TestFixtures.travel(at: TestFixtures.referenceDate)],
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input, travelsByDay: TestFixtures.travelsByDay(from: input))
        #expect(stats.travelsPerMonth.count == 1)
        #expect(stats.travelsPerMonth[0].count == 1)
    }

    // MARK: - Aggregation

    @Test("Travels in same month are aggregated into one entry")
    func sameMonthAggregated() {
        let travels = [
            TestFixtures.travel(at: TestFixtures.date(daysOffset: -2)),
            TestFixtures.travel(at: TestFixtures.referenceDate),
            TestFixtures.travel(at: TestFixtures.date(daysOffset: 2)),
        ]
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input, travelsByDay: TestFixtures.travelsByDay(from: input))
        #expect(stats.travelsPerMonth.count == 1)
        #expect(stats.travelsPerMonth[0].count == 3)
    }

    @Test("Travels across two months produce two entries")
    func twoMonths() {
        let travels = [
            TestFixtures.travel(at: TestFixtures.referenceDate), // Jan 15
            TestFixtures.travel(at: TestFixtures.date(daysOffset: 31)), // Feb 15
        ]
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input, travelsByDay: TestFixtures.travelsByDay(from: input))
        #expect(stats.travelsPerMonth.count == 2)
        #expect(stats.travelsPerMonth[0].count == 1)
        #expect(stats.travelsPerMonth[1].count == 1)
    }

    // MARK: - Gap Filling

    @Test("Gap months are filled with zero counts")
    func gapMonthsFilled() {
        // Two months apart = one gap month in between
        let travels = [
            TestFixtures.travel(at: TestFixtures.referenceDate), // Jan 15
            TestFixtures.travel(at: TestFixtures.date(daysOffset: 60)), // ~Mar 16
        ]
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input, travelsByDay: TestFixtures.travelsByDay(from: input))
        #expect(stats.travelsPerMonth.count == 3)
        #expect(stats.travelsPerMonth[0].count == 1) // Jan
        #expect(stats.travelsPerMonth[1].count == 0) // Feb (gap)
        #expect(stats.travelsPerMonth[2].count == 1) // Mar
    }

    // MARK: - 12-Month Limit

    @Test("Old months are trimmed when history exceeds window")
    func oldMonthsTrimmed() {
        // Create one travel per month for 18 months
        let travels = (0 ..< 18).map { month in
            TestFixtures.travel(at: TestFixtures.date(daysOffset: month * 31))
        }
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input, travelsByDay: TestFixtures.travelsByDay(from: input))
        #expect(stats.travelsPerMonth.count <= 13)
    }
}
