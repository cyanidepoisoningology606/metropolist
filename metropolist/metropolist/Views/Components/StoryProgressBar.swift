import SwiftUI

struct StoryProgressBar: View {
    let pageCount: Int
    let currentPage: Int
    let progress: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< pageCount, id: \.self) { index in
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.white)
                                .frame(width: segmentFillWidth(index: index, totalWidth: geo.size.width))
                        }
                        .clipShape(Capsule())
                }
                .frame(height: 3)
            }
        }
        .accessibilityHidden(true)
    }

    private func segmentFillWidth(index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentPage {
            totalWidth
        } else if index == currentPage {
            totalWidth * min(max(progress, 0), 1)
        } else {
            0
        }
    }
}
