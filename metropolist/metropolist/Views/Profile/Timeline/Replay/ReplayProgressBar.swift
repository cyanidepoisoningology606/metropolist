import SwiftUI

struct ReplayProgressBar: View {
    let viewModel: TravelReplayViewModel

    @State private var isSeeking = false

    private let trackHeight: CGFloat = 3
    private let expandedTrackHeight: CGFloat = 6
    private let gapWidth: CGFloat = 2

    private var activeTrackHeight: CGFloat {
        isSeeking ? expandedTrackHeight : trackHeight
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                segmentedTrack(width: geo.size.width, opacity: 0.25)
                segmentedTrack(width: geo.size.width, opacity: 1.0)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: fillWidth(totalWidth: geo.size.width))
                    }
            }
            .frame(height: activeTrackHeight)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { location in
                let progress = min(max(location.x / max(geo.size.width, 1), 0), 1)
                viewModel.seek(to: progress)
            }
            .gesture(seekGesture(width: geo.size.width))
        }
        .frame(height: 44)
        .animation(.easeOut(duration: 0.12), value: isSeeking)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Replay progress", comment: "Accessibility: replay scrubber"))
        .accessibilityValue(String(
            localized: "\(Int(viewModel.overallProgress * 100)) percent",
            comment: "Accessibility: replay progress value"
        ))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                viewModel.seek(to: min(viewModel.overallProgress + 0.05, 1.0))
            case .decrement:
                viewModel.seek(to: max(viewModel.overallProgress - 0.05, 0.0))
            @unknown default:
                break
            }
        }
    }

    // MARK: - Track

    private func segmentedTrack(width: CGFloat, opacity: Double) -> some View {
        HStack(spacing: gapWidth) {
            ForEach(viewModel.travelBoundaries.indices, id: \.self) { index in
                let boundary = viewModel.travelBoundaries[index]
                boundary.lineColor.opacity(opacity)
                    .frame(width: segmentWidth(boundary: boundary, totalWidth: width))
                    .clipShape(RoundedRectangle(cornerRadius: activeTrackHeight / 2))
            }
        }
        .frame(height: activeTrackHeight)
    }

    // MARK: - Helpers

    private func fillWidth(totalWidth: CGFloat) -> CGFloat {
        let boundaries = viewModel.travelBoundaries
        guard !boundaries.isEmpty, !viewModel.keyframes.isEmpty else { return 0 }

        let currentIdx = viewModel.currentIndex
        let interp = viewModel.interpolationProgress
        var filled: CGFloat = 0

        for (idx, boundary) in boundaries.enumerated() {
            if currentIdx < boundary.startIndex {
                break
            } else if currentIdx <= boundary.endIndex {
                let distanceSoFar = viewModel.cumulativeDistances[currentIdx]
                    - viewModel.cumulativeDistances[boundary.startIndex]
                    + viewModel.keyframes[currentIdx].distanceToNext * interp
                let segDist = max(boundary.segmentDistance, 1.0)
                let segWidth = segmentWidth(boundary: boundary, totalWidth: totalWidth)
                filled += segWidth * CGFloat(distanceSoFar / segDist)
                break
            } else {
                filled += segmentWidth(boundary: boundary, totalWidth: totalWidth)
                if idx < boundaries.count - 1 {
                    filled += gapWidth
                }
            }
        }

        return filled
    }

    private func segmentWidth(
        boundary: TravelReplayViewModel.TravelBoundary,
        totalWidth: CGFloat
    ) -> CGFloat {
        let gapCount = CGFloat(max(viewModel.travelBoundaries.count - 1, 0))
        let available = totalWidth - gapCount * gapWidth
        return max(0, available * CGFloat(boundary.segmentDistance / viewModel.totalDistance))
    }

    private func seekGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isSeeking {
                    isSeeking = true
                    viewModel.beginSeeking()
                }
                let progress = min(max(value.location.x / max(width, 1), 0), 1)
                viewModel.seek(to: progress)
            }
            .onEnded { _ in
                isSeeking = false
                viewModel.endSeeking()
            }
    }
}
