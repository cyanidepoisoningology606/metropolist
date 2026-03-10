import SwiftUI
import UIKit

// MARK: - Map Control Wrapper

struct MapControlWrapper: UIViewRepresentable {
    let view: UIView

    func makeUIView(context _: Context) -> UIView {
        view
    }

    func updateUIView(_: UIView, context _: Context) {}
}

// MARK: - Liquid Glass / Material Button Style

extension View {
    @ViewBuilder
    func mapButtonStyle() -> some View {
        if #available(iOS 26, *) {
            glassEffect(in: .circle)
        } else {
            background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    func mapPillStyle() -> some View {
        if #available(iOS 26, *) {
            glassEffect(in: .capsule)
        } else {
            background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    func mapCardStyle() -> some View {
        if #available(iOS 26, *) {
            glassEffect(in: .rect(cornerRadius: 16))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
