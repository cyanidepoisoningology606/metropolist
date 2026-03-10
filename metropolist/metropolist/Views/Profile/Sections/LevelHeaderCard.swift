import SwiftUI

struct LevelHeaderCard: View {
    let snapshot: GamificationSnapshot
    var totalDistance: Double?

    @State private var showXPBreakdown = false
    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CardSection {
            VStack(spacing: 16) {
                // Level circle + title
                HStack(spacing: 16) {
                    Text("\(snapshot.level.number)")
                        .font(.system(.largeTitle, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(levelGradient, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Level \(snapshot.level.number)", comment: "Profile: current level number"))
                            .font(.title3.bold())

                        Text(String(localized: "\(snapshot.totalXP) XP", comment: "Profile: total XP count"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if let firstDate = snapshot.stats.firstTravelDate {
                            Text(String(
                                localized: "Since \(firstDate.formatted(.dateTime.month(.abbreviated).day().year()))",
                                comment: "Profile: member since date"
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        if let totalDistance, totalDistance > 0 {
                            Label(
                                DistanceCalculator.formatDistance(totalDistance),
                                systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // XP progress bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let targetProgress = min(1.0, Double(snapshot.xpInCurrentLevel) / Double(snapshot.xpToNextLevel))
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.quaternary)
                                .frame(height: 8)

                            // Glow layer
                            Capsule()
                                .fill(levelGradient)
                                .frame(width: max(8, geo.size.width * animatedProgress), height: 8)
                                .blur(radius: 6)
                                .opacity(0.5)

                            Capsule()
                                .fill(levelGradient)
                                .frame(width: max(8, geo.size.width * animatedProgress), height: 8)
                        }
                        .onAppear {
                            if reduceMotion {
                                animatedProgress = targetProgress
                            } else {
                                withAnimation(.spring(duration: 0.8, bounce: 0.2)) {
                                    animatedProgress = targetProgress
                                }
                            }
                        }
                        .onChange(of: targetProgress) {
                            if reduceMotion {
                                animatedProgress = targetProgress
                            } else {
                                withAnimation(.spring(duration: 0.8, bounce: 0.2)) {
                                    animatedProgress = targetProgress
                                }
                            }
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text(String(
                            localized: "\(snapshot.xpInCurrentLevel) / \(snapshot.xpToNextLevel) XP",
                            comment: "Profile: XP progress toward next level"
                        ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Text(String(localized: "Level \(nextLevel.number)", comment: "Profile: next level number"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // XP Breakdown
                if snapshot.totalXP > 0 {
                    xpBreakdownSection
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard snapshot.totalXP > 0 else { return }
                withAnimation(reduceMotion ? .none : .snappy(duration: 0.25)) {
                    showXPBreakdown.toggle()
                }
            }
        }
    }

    private var xpBreakdownSection: some View {
        VStack(spacing: 0) {
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(showXPBreakdown ? 180 : 0))
                .animation(.spring(duration: 0.4, bounce: 0.3), value: showXPBreakdown)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .accessibilityHidden(true)

            if showXPBreakdown {
                let breakdown = snapshot.xpBreakdown
                let rows: [XPBreakdownRow] = {
                    var items: [XPBreakdownRow] = []
                    if breakdown.travelXP > 0 {
                        items.append(XPBreakdownRow(
                            icon: "tram.fill",
                            label: String(localized: "Travels", comment: "XP breakdown: travel XP"),
                            xpAmount: breakdown.travelXP
                        ))
                    }
                    if breakdown.stopXP > 0 {
                        items.append(XPBreakdownRow(
                            icon: "mappin.and.ellipse",
                            label: String(localized: "Stations", comment: "XP breakdown: station XP"),
                            xpAmount: breakdown.stopXP
                        ))
                    }
                    if breakdown.firstLineXP > 0 {
                        items.append(XPBreakdownRow(
                            icon: "sparkles",
                            label: String(localized: "Line discovery", comment: "XP breakdown: first line XP"),
                            xpAmount: breakdown.firstLineXP
                        ))
                    }
                    if breakdown.lineCompletionXP > 0 {
                        items.append(XPBreakdownRow(
                            icon: "checkmark.seal.fill",
                            label: String(localized: "Line completions", comment: "XP breakdown: line completion XP"),
                            xpAmount: breakdown.lineCompletionXP
                        ))
                    }
                    if breakdown.achievementXP > 0 {
                        items.append(XPBreakdownRow(
                            icon: "trophy.fill",
                            label: String(localized: "Achievements", comment: "XP breakdown: achievement XP"),
                            xpAmount: breakdown.achievementXP
                        ))
                    }
                    if breakdown.streakXP > 0 {
                        items.append(XPBreakdownRow(
                            icon: "flame.fill",
                            label: String(localized: "Streaks", comment: "XP breakdown: streak XP"),
                            xpAmount: breakdown.streakXP
                        ))
                    }
                    return items
                }()

                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        HStack(spacing: 10) {
                            Image(systemName: row.icon)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Text(row.label)
                                .font(.caption)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(String(localized: "\(row.xpAmount) XP", comment: "XP breakdown: amount"))
                                .font(.caption.monospacedDigit().bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var levelGradient: LinearGradient {
        let colors: [Color] = [.blue, .green, .purple, .orange, .red, .yellow]
        let index = (snapshot.level.number - 1) % colors.count
        let base = colors[index]
        return LinearGradient(colors: [base, base.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var nextLevel: PlayerLevel {
        LevelDefinitions.nextLevel(after: snapshot.level)
    }
}

private struct XPBreakdownRow: Identifiable {
    var id: String {
        icon
    }

    let icon: String
    let label: String
    let xpAmount: Int
}
