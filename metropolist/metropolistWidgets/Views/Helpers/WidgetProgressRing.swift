import SwiftUI

struct WidgetProgressRing: View {
    let progress: Double
    let gradient: LinearGradient
    var lineWidth: CGFloat = 7
    var size: CGFloat = 68

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
        }
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Progress", comment: "Accessibility: widget progress ring label"))
        .accessibilityValue(String(
            localized: "\(Int((clampedProgress * 100).rounded())) percent",
            comment: "Accessibility: widget progress ring value"
        ))
    }

    private var clampedProgress: Double {
        min(1.0, max(0, progress))
    }
}
