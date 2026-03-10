import SwiftUI

struct LineCertificateSheet: View {
    let data: LineCertificateData
    @Environment(\.dismiss) private var dismiss

    @Environment(\.displayScale) private var displayScale
    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    LineCertificateView(data: data)
                        .padding(.top, 16)

                    if let image = renderedImage {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview(
                                String(
                                    localized: "Line \(data.lineShortName) Certificate",
                                    comment: "Certificate: share preview title"
                                ),
                                image: Image(uiImage: image)
                            )
                        ) {
                            Label(
                                String(localized: "Share Certificate", comment: "Certificate: share button"),
                                systemImage: "square.and.arrow.up"
                            )
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "Certificate", comment: "Certificate: sheet navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done", comment: "Certificate: dismiss button")) {
                        dismiss()
                    }
                }
            }
            .task {
                renderImage()
            }
        }
    }

    @MainActor
    private func renderImage() {
        let renderer = ImageRenderer(
            content: LineCertificateView(data: data)
                .padding(20)
                .background(Color(red: 0.96, green: 0.95, blue: 0.93))
                .environment(\.colorScheme, .light)
        )
        renderer.scale = displayScale
        renderedImage = renderer.uiImage
    }
}
