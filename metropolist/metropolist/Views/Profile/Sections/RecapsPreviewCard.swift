import SwiftUI

struct RecapsPreviewCard: View {
    let summaries: [RecapSummary]
    @Environment(\.openRecap) private var openRecap

    var body: some View {
        VStack(spacing: 12) {
            if summaries.isEmpty {
                emptyContent
            } else {
                storiesRow

                NavigationLink(value: GamificationDestination.recaps) {
                    HStack {
                        Label(
                            String(localized: "All Recaps", comment: "Recap preview: all recaps link"),
                            systemImage: "calendar"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Content

private extension RecapsPreviewCard {
    var storiesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(summaries) { summary in
                    if summary.isYearly {
                        YearlyStoryCircle(summary: summary) {
                            openRecap(summary.kind)
                        }
                    } else {
                        MonthlyStoryCircle(summary: summary) {
                            openRecap(summary.kind)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    var emptyContent: some View {
        NavigationLink(value: GamificationDestination.recaps) {
            HStack {
                Label(
                    String(localized: "Recaps", comment: "Recap preview: empty state link"),
                    systemImage: "calendar"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Monthly Story Circle

private struct MonthlyStoryCircle: View {
    let summary: RecapSummary
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 56

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    summary.dominantModeColor,
                                    summary.dominantModeColor.opacity(0.4),
                                    summary.dominantModeColor,
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: circleSize, height: circleSize)

                    Circle()
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .frame(width: circleSize - 8, height: circleSize - 8)

                    Text(summary.abbreviatedLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Circle()
                    .fill(.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                "\(summary.formattedTitle), \(summary.travelCount) travels",
                comment: "Recap preview: story circle accessibility label"
            )
        )
    }
}

// MARK: - Yearly Story Circle

private struct YearlyStoryCircle: View {
    let summary: RecapSummary
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var baseSize: CGFloat = 56

    private var circleSize: CGFloat {
        baseSize * 1.2
    }

    private var ringColors: [Color] {
        let colors = summary.topModeColors
        guard colors.count >= 2 else {
            let fallback = summary.dominantModeColor
            return [fallback, fallback.opacity(0.4), fallback]
        }
        return colors + [colors[0]]
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(colors: ringColors, center: .center),
                            lineWidth: 4
                        )
                        .frame(width: circleSize, height: circleSize)

                    Circle()
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .frame(width: circleSize - 10, height: circleSize - 10)

                    Text(summary.abbreviatedLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Circle()
                    .fill(.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                "\(summary.formattedTitle), \(summary.travelCount) travels",
                comment: "Recap preview: yearly story circle accessibility label"
            )
        )
    }
}
