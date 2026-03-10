import SwiftUI
import TransitModels

// MARK: - Certificate & Teaser Helpers

extension TravelSuccessView {
    func buildCertificateData() -> LineCertificateData? {
        guard let line = viewModel.selectedLine,
              let celebration = viewModel.celebrationEvent else { return nil }
        let mode = TransitMode(rawValue: line.mode) ?? .bus
        let travelCount = (logged { try viewModel.dataStore.userService.travelCount(forLineSourceID: line.sourceID) }) ?? 1
        let firstTravel = (try? viewModel.dataStore.userService.firstTravelDate(forLineSourceID: line.sourceID))
            ?? viewModel.travelDate
        let totalStations = (logged {
            try viewModel.dataStore.transitService.stationSourceIDs(forLineSourceID: line.sourceID).count
        }) ?? 0
        return LineCertificateData(
            sourceId: line.sourceID,
            lineShortName: line.shortName,
            lineLongName: line.longName,
            lineColor: line.color,
            lineTextColor: line.textColor,
            mode: mode,
            totalStations: totalStations,
            travelCount: travelCount,
            firstTravelDate: firstTravel,
            completionDate: viewModel.travelDate,
            playerLevel: celebration.levelProgress.afterLevel.number
        )
    }

    func teaserText(_ teaser: CelebrationTeaser) -> Text {
        switch teaser {
        case let .stopsToNextBadge(lineShortName, stopsRemaining, nextTier):
            Text(String(
                localized: "Only \(stopsRemaining) more stops to \(nextTier.label) on Line \(lineShortName)!",
                comment: "Travel success: teaser for next badge tier"
            ))
        case let .xpToNextLevel(xpRemaining, nextLevel):
            Text(String(
                localized: "\(xpRemaining) XP to Level \(nextLevel.number)",
                comment: "Travel success: teaser for next level"
            ))
        }
    }
}
