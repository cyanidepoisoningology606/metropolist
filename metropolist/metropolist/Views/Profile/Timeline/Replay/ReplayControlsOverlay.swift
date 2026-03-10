import SwiftUI
import TransitModels

struct ReplayControlsOverlay: View {
    let viewModel: TravelReplayViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal)
                .padding(.top, 8)

            Spacer()
                .allowsHitTesting(false)

            ReplayLineBadgeLabel(viewModel: viewModel)
                .padding(.bottom, 12)

            bottomBar
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .replayPill()
            .accessibilityLabel(String(localized: "Close", comment: "Accessibility: close replay"))

            ReplayStationInfoLabel(viewModel: viewModel)

            Spacer()
                .allowsHitTesting(false)

            Button {
                cycleSpeed()
            } label: {
                Text(viewModel.speed.label)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .replayPill()
            .accessibilityLabel(String(localized: "Speed", comment: "Accessibility: speed picker"))
            .accessibilityValue(viewModel.speed.label)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            ReplayProgressBar(viewModel: viewModel)
                .padding(.horizontal, 16)

            HStack(spacing: 16) {
                playPauseButton

                Spacer(minLength: 0)

                ReplayDistanceLabel(viewModel: viewModel)

                Spacer(minLength: 0)

                if viewModel.travelBoundaries.count > 1 {
                    ReplayTravelCounterLabel(viewModel: viewModel)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background { replayBarBackground }
    }

    // MARK: - Play/Pause

    private var playPauseButton: some View {
        Button {
            viewModel.togglePlayback()
        } label: {
            Image(systemName: playButtonIcon)
                .font(.title3.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playButtonAccessibilityLabel)
    }

    // MARK: - Helpers

    private var playButtonIcon: String {
        if viewModel.isFinished {
            "arrow.counterclockwise"
        } else if viewModel.isPlaying {
            "pause.fill"
        } else {
            "play.fill"
        }
    }

    private var playButtonAccessibilityLabel: String {
        if viewModel.isFinished {
            String(localized: "Replay", comment: "Accessibility: replay button")
        } else if viewModel.isPlaying {
            String(localized: "Pause", comment: "Accessibility: pause button")
        } else {
            String(localized: "Play", comment: "Accessibility: play button")
        }
    }

    private func cycleSpeed() {
        let all = TravelReplayViewModel.ReplaySpeed.allCases
        let idx = all.firstIndex(of: viewModel.speed) ?? 0
        viewModel.setSpeed(all[(idx + 1) % all.count])
    }
}

// MARK: - Per-Frame Isolated Views

/// Isolated view that only re-evaluates when `currentStationInfo` changes.
private struct ReplayStationInfoLabel: View {
    let viewModel: TravelReplayViewModel

    var body: some View {
        if let stationInfo = viewModel.currentStationInfo {
            HStack(spacing: 4) {
                Text(stationInfo.name)
                    .font(.subheadline.weight(.medium))
                if !stationInfo.destination.isEmpty {
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(stationInfo.destination)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .replayPill()
            .transition(.opacity)
            .id(stationInfo.name)
        }
    }
}

/// Isolated view that only re-evaluates when `currentLine` changes.
private struct ReplayLineBadgeLabel: View {
    let viewModel: TravelReplayViewModel

    var body: some View {
        if let line = viewModel.currentLine {
            LineBadge(line: line)
                .allowsHitTesting(false)
        }
    }
}

/// Isolated view that only re-evaluates when `currentDistance` changes,
/// preventing the parent overlay from re-evaluating every frame.
private struct ReplayDistanceLabel: View {
    let viewModel: TravelReplayViewModel

    var body: some View {
        Text(DistanceCalculator.formatDistance(viewModel.currentDistance))
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
    }
}

/// Isolated view that only re-evaluates when `currentIndex` changes.
private struct ReplayTravelCounterLabel: View {
    let viewModel: TravelReplayViewModel

    var body: some View {
        Text(String(
            localized: "\(currentTravelNumber)/\(viewModel.travelBoundaries.count)",
            comment: "Replay: travel counter compact"
        ))
        .font(.subheadline.weight(.medium))
        .monospacedDigit()
    }

    private var currentTravelNumber: Int {
        guard !viewModel.keyframes.isEmpty else { return 0 }
        let id = viewModel.keyframes[viewModel.currentIndex].travelID
        return (viewModel.travelBoundaries.firstIndex { $0.travelID == id } ?? 0) + 1
    }
}

// MARK: - Styles

private extension ReplayControlsOverlay {
    @ViewBuilder
    var replayBarBackground: some View {
        if #available(iOS 26, *) {
            Color.clear
                .glassEffect(in: .rect)
                .ignoresSafeArea(edges: .bottom)
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

private extension View {
    @ViewBuilder
    func replayPill() -> some View {
        if #available(iOS 26, *) {
            glassEffect(in: .capsule)
        } else {
            background(.ultraThinMaterial, in: Capsule())
        }
    }
}
