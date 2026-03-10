import SwiftUI

// MARK: - Certificate

extension LineDetailView {
    func certificateButton(_ data: LineCertificateData) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showCertificateSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "scroll.fill")
                    .font(.title3)
                    .foregroundStyle(BadgeTier.gold.color)

                Text(String(
                    localized: "View Completion Certificate",
                    comment: "Line detail: certificate button"
                ))
                .font(.subheadline.weight(.semibold))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCertificateSheet) {
            LineCertificateSheet(data: data)
        }
    }
}
