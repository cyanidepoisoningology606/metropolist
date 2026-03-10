import SwiftUI

// MARK: - Story Background

struct StoryBackground: View {
    let page: RecapStoryPage
    let color: Color

    var body: some View {
        let config = backgroundConfig(for: page)
        LinearGradient(colors: config.colors, startPoint: config.start, endPoint: config.end)
            .ignoresSafeArea()
    }

    private func backgroundConfig(for page: RecapStoryPage) -> BackgroundConfig {
        switch page {
        case .hero:
            BackgroundConfig(
                colors: [color.opacity(0.6), color.opacity(0.2), .black],
                start: .top, end: .bottom
            )
        case .numbers:
            BackgroundConfig(
                colors: [.black, color.opacity(0.3), .black],
                start: .topLeading, end: .bottomTrailing
            )
        case .discoveries:
            BackgroundConfig(
                colors: [color.opacity(0.15), .indigo.opacity(0.2), .black],
                start: .topTrailing, end: .bottomLeading
            )
        case .distance:
            BackgroundConfig(
                colors: [.teal.opacity(0.3), color.opacity(0.15), .black],
                start: .topLeading, end: .bottomTrailing
            )
        case .topLine:
            BackgroundConfig(
                colors: [color.opacity(0.5), color.opacity(0.15), .black.opacity(0.95)],
                start: .bottom, end: .top
            )
        case .leveledUp:
            BackgroundConfig(
                colors: [.yellow.opacity(0.15), .orange.opacity(0.1), .black],
                start: .topLeading, end: .bottomTrailing
            )
        case .summary:
            BackgroundConfig(
                colors: [color.opacity(0.5), .purple.opacity(0.15), .black],
                start: .topLeading, end: .bottomTrailing
            )
        }
    }
}

private struct BackgroundConfig {
    let colors: [Color]
    let start: UnitPoint
    let end: UnitPoint
}

// MARK: - Floating Background Shapes

struct FloatingShapesBackground: View {
    let color: Color
    let shapeCount: Int

    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ForEach(0 ..< shapeCount, id: \.self) { index in
                let seed = shapeSeed(index: index)
                Circle()
                    .fill(color.opacity(seed.opacity))
                    .blur(radius: seed.blur)
                    .frame(width: seed.size, height: seed.size)
                    .position(
                        x: geo.size.width * seed.startX + (animate ? seed.driftX : 0),
                        y: geo.size.height * seed.startY + (animate ? seed.driftY : 0)
                    )
                    .scaleEffect(animate ? seed.scaleEnd : seed.scaleStart)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .onDisappear {
            animate = false
        }
    }

    private func shapeSeed(index: Int) -> ShapeSeed {
        let angle = Double(index) * 2.39996 // golden angle
        return ShapeSeed(
            startX: 0.2 + CGFloat(index % 3) * 0.3,
            startY: 0.15 + CGFloat(index % 4) * 0.2,
            driftX: CGFloat(cos(angle)) * 25,
            driftY: CGFloat(sin(angle)) * 20,
            size: CGFloat(60 + (index % 3) * 30),
            blur: CGFloat(20 + (index % 2) * 15),
            opacity: 0.06 + Double(index % 3) * 0.02,
            scaleStart: 0.9,
            scaleEnd: 1.1
        )
    }
}

private struct ShapeSeed {
    let startX: CGFloat
    let startY: CGFloat
    let driftX: CGFloat
    let driftY: CGFloat
    let size: CGFloat
    let blur: CGFloat
    let opacity: Double
    let scaleStart: CGFloat
    let scaleEnd: CGFloat
}

// MARK: - Mini Stat

struct StoryMiniStat: View {
    let icon: String
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            Text("\(value)")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(value) \(label)", comment: "Story mini stat: value followed by label"))
    }
}

// MARK: - Numbers Delta Pill

struct NumbersDeltaPill: View {
    let current: Int
    let previous: Int

    private var delta: Int {
        current - previous
    }

    var body: some View {
        if delta != 0 {
            let isPositive = delta > 0
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                    .font(.caption2.bold())
                Text("\(abs(delta)) from last month", comment: "Numbers: delta from previous month")
                    .font(.caption2)
            }
            .foregroundStyle(isPositive ? .green : .red)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                (isPositive ? Color.green : Color.red).opacity(0.2),
                in: Capsule()
            )
        }
    }
}

// MARK: - Hero Tagline

enum RecapCopy {
    static func heroTagline(_ snapshot: MonthlySnapshot) -> String {
        if snapshot.activeDays >= 5, snapshot.activeDays >= daysInMonth(snapshot.month) {
            return String(localized: "You didn't miss a single day", comment: "Recap hero: shown when user traveled every day of the month")
        }
        if snapshot.uniqueStationsDiscovered.count > 15 {
            return String(
                localized: "You discovered \(snapshot.uniqueStationsDiscovered.count) new stops",
                comment: "Recap hero: shown when many new stations discovered"
            )
        }
        if snapshot.travelCount > 50 {
            return String(
                localized: "\(snapshot.travelCount) travels. You practically live on the network.",
                comment: "Recap hero: shown when over 50 travels in a month"
            )
        }
        if snapshot.linesStarted.count >= 3 {
            return String(
                localized: "You branched out to \(snapshot.linesStarted.count) new lines",
                comment: "Recap hero: shown when user tried 3+ new lines"
            )
        }
        if snapshot.bestStreak >= 7 {
            return String(
                localized: "\(snapshot.bestStreak) days straight. Unstoppable.",
                comment: "Recap hero: shown when streak is 7+ days"
            )
        }
        if snapshot.travelCount > 20 {
            return String(localized: "A solid month on the network", comment: "Recap hero: shown when over 20 travels")
        }
        if snapshot.activeDays >= 15 {
            return String(localized: "Out there almost every day", comment: "Recap hero: shown when 15+ active days")
        }
        return String(localized: "Your month in review", comment: "Recap hero: default fallback tagline")
    }

    private static func daysInMonth(_ month: DateComponents) -> Int {
        let cal = Calendar.current
        guard let date = cal.date(from: month),
              let range = cal.range(of: .day, in: .month, for: date)
        else {
            return 31
        }
        return range.count
    }
}
