import SwiftUI

// MARK: - Summary Header

struct BadgesSummaryHeader: View {
    let snapshot: GamificationSnapshot
    let linesByMode: [(mode: TransitMode, lines: [LineMetadata])]

    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 72

    private var earnedBadges: Int {
        snapshot.lineBadges.values.reduce(0) { $0 + $1.rawValue }
    }

    private var totalBadges: Int {
        linesByMode.reduce(0) { $0 + $1.lines.count } * 3
    }

    private var completedStops: Int {
        linesByMode.reduce(0) { total, group in
            total + group.lines.reduce(0) { $0 + (snapshot.lineProgress[$1.sourceID]?.completedStops ?? 0) }
        }
    }

    private var totalStops: Int {
        linesByMode.reduce(0) { $0 + $1.lines.reduce(0) { $0 + $1.totalStations } }
    }

    var body: some View {
        HStack(spacing: 16) {
            CompletionRing(
                completed: earnedBadges,
                total: totalBadges,
                size: ringSize
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "\(earnedBadges) of \(totalBadges)", comment: "Badges: earned count ratio"))
                    .font(.title3.weight(.bold).monospacedDigit())

                Text(String(localized: "badges earned", comment: "Badges: earned count subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(
                    localized: "\(completedStops)/\(totalStops) stops visited",
                    comment: "Badges: overall stop progress"
                ))
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
    }
}

// MARK: - Mode Filter

struct BadgesModeFilter: View {
    let snapshot: GamificationSnapshot
    let linesByMode: [(mode: TransitMode, lines: [LineMetadata])]
    @Binding var selectedMode: TransitMode?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var totalEarned: Int {
        snapshot.lineBadges.values.reduce(0) { $0 + $1.rawValue }
    }

    private var totalBadges: Int {
        linesByMode.reduce(0) { $0 + $1.lines.count } * 3
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    icon: "medal.fill",
                    name: String(localized: "All", comment: "Badges: filter chip showing all modes"),
                    count: totalEarned,
                    total: totalBadges,
                    tint: .primary,
                    isSelected: selectedMode == nil
                ) {
                    withAnimation(reduceMotion ? .none : .snappy(duration: 0.25)) {
                        selectedMode = nil
                    }
                }

                ForEach(linesByMode, id: \.mode) { group in
                    let count = group.lines.reduce(0) {
                        $0 + (snapshot.lineBadges[$1.sourceID]?.rawValue ?? 0)
                    }

                    FilterChip(
                        icon: group.mode.systemImage,
                        name: group.mode.label,
                        count: count,
                        total: group.lines.count * 3,
                        tint: group.mode.tintColor,
                        isSelected: selectedMode == group.mode
                    ) {
                        withAnimation(reduceMotion ? .none : .snappy(duration: 0.25)) {
                            selectedMode = group.mode
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }
}

// MARK: - Badges Line List

struct BadgesLineList: View {
    let snapshot: GamificationSnapshot
    let linesByMode: [(mode: TransitMode, sortedLines: [LineMetadata])]
    let selectedMode: TransitMode?

    private func completedStops(for lines: [LineMetadata]) -> Int {
        lines.reduce(0) { $0 + (snapshot.lineProgress[$1.sourceID]?.completedStops ?? 0) }
    }

    private func totalStops(for lines: [LineMetadata]) -> Int {
        lines.reduce(0) { $0 + $1.totalStations }
    }

    var body: some View {
        if let mode = selectedMode {
            if let group = linesByMode.first(where: { $0.mode == mode }) {
                Section {
                    ForEach(group.sortedLines, id: \.sourceID) { meta in
                        RichLineBadgeCard(
                            meta: meta,
                            tier: snapshot.lineBadges[meta.sourceID] ?? .locked,
                            progress: snapshot.lineProgress[meta.sourceID]
                        )
                    }
                } header: {
                    ModeSectionHeader(
                        mode: group.mode,
                        completedStops: completedStops(for: group.sortedLines),
                        totalStops: totalStops(for: group.sortedLines)
                    )
                    .padding(.bottom, 4)
                }
            }
        } else {
            ForEach(linesByMode, id: \.mode) { group in
                Section {
                    ForEach(group.sortedLines, id: \.sourceID) { meta in
                        RichLineBadgeCard(
                            meta: meta,
                            tier: snapshot.lineBadges[meta.sourceID] ?? .locked,
                            progress: snapshot.lineProgress[meta.sourceID]
                        )
                    }
                } header: {
                    ModeSectionHeader(
                        mode: group.mode,
                        completedStops: completedStops(for: group.sortedLines),
                        totalStops: totalStops(for: group.sortedLines)
                    )
                    .padding(.bottom, 4)
                }
            }
        }
    }
}

// MARK: - Mode Section Header

private struct ModeSectionHeader: View {
    let mode: TransitMode
    let completedStops: Int
    let totalStops: Int

    var body: some View {
        HStack {
            Label(mode.label, systemImage: mode.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(mode.tintColor)

            Spacer()

            Text(String(
                localized: "\(completedStops)/\(totalStops) stops",
                comment: "Badges: completed stops out of total stops for a mode"
            ))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

// MARK: - Rich Line Badge Card

private struct RichLineBadgeCard: View {
    let meta: LineMetadata
    let tier: BadgeTier
    let progress: LineProgress?

    private var isLocked: Bool {
        tier == .locked
    }

    private var completedStops: Int {
        progress?.completedStops ?? 0
    }

    private var fraction: Double {
        progress?.fraction ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // Line badge pill
            Text(meta.shortName)
                .font(.caption2.bold())
                .foregroundStyle(Color(hex: meta.textColor))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(minWidth: 32, minHeight: 24)
                .background(Color(hex: meta.color), in: RoundedRectangle(cornerRadius: 4))

            // Name + progress
            VStack(alignment: .leading, spacing: 4) {
                Text(meta.longName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(1)

                ProgressView(value: fraction)
                    .tint(isLocked ? Color.gray.opacity(0.3) : Color(hex: meta.color))

                Text(String(
                    localized: "\(completedStops)/\(meta.totalStations) stops",
                    comment: "Badges: completed stops out of total stops"
                ))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isLocked ? .tertiary : .secondary)
            }

            Spacer(minLength: 0)

            // Tier indicator
            VStack(spacing: 2) {
                Image(systemName: tier.systemImage)
                    .font(.body)
                    .foregroundStyle(tier.color)

                if !isLocked {
                    Text(tier.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 48)
        }
        .padding(12)
        .opacity(isLocked ? 0.65 : 1)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
    }
}
