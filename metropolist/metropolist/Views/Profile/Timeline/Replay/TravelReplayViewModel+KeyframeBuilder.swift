import CoreLocation
import SwiftUI
import TransitModels

private let trainModes: Set<String> = [
    TransitMode.rer.rawValue,
    TransitMode.train.rawValue,
    TransitMode.regionalRail.rawValue,
]

extension TravelReplayViewModel {
    static func buildKeyframes(
        travels: [Travel],
        segments: [TimelineViewModel.TravelMapSegment],
        lines: [String: TransitLine],
        stationNames: [String: String]
    ) -> ([ReplayKeyframe], [TravelBoundary]) {
        let segmentsByID = Dictionary(uniqueKeysWithValues: segments.map { ($0.id, $0) })
        var keyframes: [ReplayKeyframe] = []
        var boundaries: [TravelBoundary] = []

        for (travelIndex, travel) in travels.enumerated() {
            guard let segment = segmentsByID[travel.id] else { continue }
            let startIndex = keyframes.count

            let mode = lines[travel.lineSourceID]?.mode ?? ""
            let speedMultiplier: Double = trainModes.contains(mode) ? 2.0 : 1.0

            for (coordIndex, coordinate) in segment.coordinates.enumerated() {
                let isFirst = coordIndex == 0
                let isLast = coordIndex == segment.coordinates.count - 1

                let name: String = if isFirst {
                    stationNames[travel.fromStationSourceID] ?? ""
                } else if isLast {
                    stationNames[travel.toStationSourceID] ?? ""
                } else {
                    ""
                }

                let distanceToNext: Double
                if isLast {
                    distanceToNext = 0
                } else {
                    let next = segment.coordinates[coordIndex + 1]
                    let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    let destination = CLLocation(latitude: next.latitude, longitude: next.longitude)
                    distanceToNext = max(origin.distance(from: destination), 1.0)
                }

                keyframes.append(ReplayKeyframe(
                    coordinate: coordinate,
                    travelID: travel.id,
                    stationName: name,
                    lineColor: segment.lineColor,
                    lineSourceID: travel.lineSourceID,
                    isTransfer: isFirst && travelIndex > 0,
                    isEndpoint: isFirst || isLast,
                    distanceToNext: distanceToNext,
                    speedMultiplier: speedMultiplier
                ))
            }

            let endIndex = keyframes.count - 1
            if startIndex <= endIndex {
                let segmentDistance = keyframes[startIndex ... endIndex]
                    .reduce(0.0) { $0 + $1.distanceToNext }
                boundaries.append(TravelBoundary(
                    travelID: travel.id,
                    startIndex: startIndex,
                    endIndex: endIndex,
                    lineColor: segment.lineColor,
                    coordinates: segment.coordinates,
                    segmentDistance: segmentDistance
                ))
            }
        }

        return (keyframes, boundaries)
    }

    static func buildStationInfoLookup(keyframes: [ReplayKeyframe]) -> [StationInfo?] {
        guard !keyframes.isEmpty else { return [] }
        // Forward pass: compute "next station" for each index
        var nextStation = Array(repeating: "", count: keyframes.count)
        var upcoming = ""
        for idx in stride(from: keyframes.count - 1, through: 0, by: -1) {
            if !keyframes[idx].stationName.isEmpty {
                upcoming = keyframes[idx].stationName
            }
            nextStation[idx] = upcoming
        }

        // Backward pass: compute "current station" and combine
        var result: [StationInfo?] = Array(repeating: nil, count: keyframes.count)
        var currentName = ""
        for idx in 0 ..< keyframes.count {
            if !keyframes[idx].stationName.isEmpty {
                currentName = keyframes[idx].stationName
            }
            guard !currentName.isEmpty else { continue }
            let dest: String = if idx + 1 < keyframes.count {
                nextStation[idx + 1]
            } else {
                ""
            }
            result[idx] = StationInfo(name: currentName, destination: dest == currentName ? "" : dest)
        }
        return result
    }
}
