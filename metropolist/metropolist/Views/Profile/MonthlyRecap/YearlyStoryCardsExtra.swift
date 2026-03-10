import SwiftUI

// MARK: - Mode Breakdown Page

struct WrappedModeBreakdownPage: View {
    let viewModel: YearlyRecapViewModel
    let snapshot: YearlySnapshot
    let animationPhase: Int

    private var sortedModes: [(TransitMode, Int)] {
        snapshot.modeBreakdown.sorted { $0.value > $1.value }
    }

    private var totalCount: Int {
        snapshot.modeBreakdown.values.reduce(0, +)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [viewModel.accentColor.opacity(0.2), .indigo.opacity(0.15), .black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(String(localized: "HOW YOU TRAVELED", comment: "Wrapped mode breakdown: heading"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
                    .opacity(animationPhase >= 1 ? 1 : 0)

                modeBarStack
                    .opacity(animationPhase >= 2 ? 1 : 0)

                modeLegend
                    .opacity(animationPhase >= 3 ? 1 : 0)
                    .offset(y: animationPhase >= 3 ? 0 : 15)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -20)
        }
        .accessibilityElement(children: .combine)
    }

    private var modeBarStack: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(sortedModes, id: \.0) { mode, count in
                    let fraction = totalCount > 0 ? CGFloat(count) / CGFloat(totalCount) : 0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(mode.tintColor)
                        .frame(width: max(4, fraction * geo.size.width))
                }
            }
        }
        .frame(height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var modeLegend: some View {
        VStack(spacing: 8) {
            ForEach(sortedModes, id: \.0) { mode, count in
                let percentage = totalCount > 0 ? Int(Double(count) / Double(totalCount) * 100) : 0
                HStack(spacing: 10) {
                    Circle()
                        .fill(mode.tintColor)
                        .frame(width: 10, height: 10)
                    Image(systemName: mode.systemImage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 20)
                    Text(mode.label)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(percentage)%", comment: "Wrapped mode breakdown: percentage for transit mode")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(count)", comment: "Wrapped mode breakdown: travel count for transit mode")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Wrapped Discoveries Page

struct WrappedDiscoveriesPage: View {
    let viewModel: YearlyRecapViewModel
    let animationPhase: Int

    @ScaledMetric(relativeTo: .largeTitle) private var stationCountSize: CGFloat = 64

    private var discoveries: ResolvedDiscoveries {
        viewModel.resolvedDiscoveries
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [viewModel.accentColor.opacity(0.15), .indigo.opacity(0.2), .black],
                startPoint: .topTrailing, endPoint: .bottomLeading
            )
            .ignoresSafeArea()
            FloatingShapesBackground(color: viewModel.accentColor, shapeCount: 3)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Text(String(localized: "DISCOVERIES", comment: "Wrapped discoveries: section heading"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(3)
                        .opacity(animationPhase >= 1 ? 1 : 0)

                    if !discoveries.newStations.isEmpty {
                        stationCountHero
                            .opacity(animationPhase >= 2 ? 1 : 0)
                            .scaleEffect(animationPhase >= 2 ? 1 : 0.6)
                    }

                    if !discoveries.newLines.isEmpty {
                        linesGrid
                            .opacity(animationPhase >= 3 ? 1 : 0)
                            .offset(y: animationPhase >= 3 ? 0 : 20)
                    }

                    if !discoveries.newStations.isEmpty {
                        stationsList
                            .opacity(animationPhase >= 4 ? 1 : 0)
                            .offset(y: animationPhase >= 4 ? 0 : 15)
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 80)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var stationCountHero: some View {
        VStack(spacing: 6) {
            Text("\(discoveries.newStations.count)", comment: "Wrapped discoveries: number of new stations discovered")
                .font(.system(size: min(stationCountSize, 72), weight: .heavy).monospacedDigit())
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
            Text(String(localized: "new stops discovered this year", comment: "Wrapped discoveries: label"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var linesGrid: some View {
        VStack(spacing: 10) {
            Text(String(localized: "New Lines", comment: "Wrapped discoveries: new lines heading"))
                .font(.caption.weight(.black))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)

            FlowLayout(spacing: 8) {
                ForEach(discoveries.newLines) { line in
                    Text(line.shortName)
                        .font(.footnote.bold())
                        .foregroundStyle(line.textColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 36, minHeight: 28)
                        .background(line.color, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: line.color.opacity(0.4), radius: 8, y: 2)
                }
            }
        }
    }

    private var stationsList: some View {
        VStack(spacing: 6) {
            Text(String(localized: "New Stops", comment: "Wrapped discoveries: new stops heading"))
                .font(.caption.weight(.black))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            let displayStations = Array(discoveries.newStations.prefix(10))
            let remaining = discoveries.newStations.count - displayStations.count

            VStack(spacing: 0) {
                ForEach(displayStations) { station in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(viewModel.accentColor)
                            .frame(width: 6, height: 6)
                        Text(station.name)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }

                if remaining > 0 {
                    Text(String(
                        localized: "+\(remaining) more",
                        comment: "Wrapped discoveries: remaining station count"
                    ))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                }
            }
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Wrapped Leveled Up Page

struct WrappedLeveledUpPage: View {
    let viewModel: YearlyRecapViewModel
    let animationPhase: Int

    @State private var showConfetti = false
    @State private var confettiTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.yellow.opacity(0.15), .orange.opacity(0.1), .black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            FloatingShapesBackground(color: .yellow, shapeCount: 4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                        .scaleEffect(animationPhase >= 1 ? 1 : 0.3)
                        .opacity(animationPhase >= 1 ? 1 : 0)

                    Text(String(localized: "LEVELED UP", comment: "Wrapped leveled up: heading"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(3)
                        .opacity(animationPhase >= 2 ? 1 : 0)

                    Text(
                        "\(viewModel.resolvedBadgeUpgrades.count) badge upgrades this year",
                        comment: "Wrapped leveled up: subtitle"
                    )
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .opacity(animationPhase >= 3 ? 1 : 0)

                    upgradesList
                        .opacity(animationPhase >= 4 ? 1 : 0)
                        .offset(y: animationPhase >= 4 ? 0 : 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 80)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(true)

            if !reduceMotion {
                ConfettiView(isActive: showConfetti, color: .yellow)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: animationPhase) {
            if animationPhase >= 4 {
                confettiTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    showConfetti = true
                }
            }
        }
        .onDisappear { confettiTask?.cancel() }
        .accessibilityElement(children: .combine)
    }

    private var upgradesList: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.resolvedBadgeUpgrades, id: \.lineSourceID) { upgrade in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(upgrade.lineColor)
                        .frame(width: 4)
                        .padding(.trailing, 10)

                    Text(upgrade.shortName)
                        .font(.caption2.bold())
                        .foregroundStyle(upgrade.lineTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .frame(minWidth: 32, minHeight: 24)
                        .background(upgrade.lineColor, in: RoundedRectangle(cornerRadius: 4))

                    Spacer()

                    Text(upgrade.newTier.label)
                        .font(.caption.bold())
                        .foregroundStyle(upgrade.newTier.color)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
