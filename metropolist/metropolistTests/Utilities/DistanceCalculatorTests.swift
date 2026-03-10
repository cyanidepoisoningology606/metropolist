@testable import metropolist
import Testing

@MainActor
struct DistanceCalculatorTests {
    @Test("formatDistance renders meters for short distances")
    func formatDistanceMeters() {
        let result = DistanceCalculator.formatDistance(300)
        #expect(result.contains("m"))
        #expect(result.contains("300"))
    }

    @Test("formatDistance renders kilometers for long distances")
    func formatDistanceKilometers() {
        let result = DistanceCalculator.formatDistance(1500)
        #expect(result.contains("km"))
        #expect(result.contains("1.5"))
    }

    @Test("formatDistance renders 0 m for zero distance")
    func formatDistanceZero() {
        let result = DistanceCalculator.formatDistance(0)
        #expect(result.contains("0"))
        #expect(result.contains("m"))
    }
}
