import CryptoKit
import SwiftUI

struct LineCertificateData: Identifiable {
    var id: String {
        sourceId
    }

    let sourceId: String
    let lineShortName: String
    let lineLongName: String
    let lineColor: String
    let lineTextColor: String
    let mode: TransitMode
    let totalStations: Int
    let travelCount: Int
    let firstTravelDate: Date
    let completionDate: Date
    let playerLevel: Int
}

struct LineCertificateView: View {
    let data: LineCertificateData

    private var lineColor: Color {
        Color(hex: data.lineColor)
    }

    private var textColor: Color {
        Color(hex: data.lineTextColor)
    }

    private var duration: String {
        let cal = Calendar.current
        let start = cal.startOfDay(for: data.firstTravelDate)
        let end = cal.startOfDay(for: data.completionDate)

        if start == end {
            return String(localized: "Same day", comment: "Certificate: completed in one day")
        }

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 3
        formatter.allowedUnits = [.year, .month, .day]
        return formatter.string(from: start, to: end) ?? ""
    }

    private var certificateNumber: String {
        let cal = Calendar.current
        let year = cal.component(.year, from: data.completionDate)
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: data.completionDate) ?? 1
        let digest = SHA256.hash(data: Data(data.sourceId.utf8))
        let hex = digest.prefix(3).map { String(format: "%02X", $0) }.joined()
        return String(format: "#M-%04d-%03d-%@", year, dayOfYear, hex)
    }

    // MARK: - Background Color

    private static let parchment = Color(red: 0.99, green: 0.97, blue: 0.94)

    var body: some View {
        VStack(spacing: 0) {
            // Top accent bar
            lineColor
                .frame(height: 6)

            VStack(spacing: 16) {
                header
                certificateDivider
                statsGrid
                certificateDivider
                footer
            }
            .padding(24)

            // Bottom accent bar
            lineColor
                .frame(height: 6)
        }
        .frame(width: 360)
        .background(Self.parchment)
        .clipShape(Rectangle())
        .overlay(parchmentVignette)
        .colorEffect(
            ShaderLibrary.paperGrain(
                .float2(360, 500),
                .float(0.04)
            )
        )
        .overlay(doubleBorder)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }

    // MARK: - Decorative Elements

    private var doubleBorder: some View {
        ZStack {
            Rectangle()
                .strokeBorder(lineColor.opacity(0.3), lineWidth: 1.5)
            Rectangle()
                .strokeBorder(lineColor.opacity(0.15), lineWidth: 0.5, antialiased: true)
                .padding(5)
        }
    }

    private var parchmentVignette: some View {
        RadialGradient(
            colors: [
                .clear,
                Color(red: 0.85, green: 0.82, blue: 0.78).opacity(0.15),
            ],
            center: .center,
            startRadius: 60,
            endRadius: 250
        )
    }

    private var certificateDivider: some View {
        HStack(spacing: 8) {
            line
            Image(systemName: "diamond.fill")
                .font(.system(size: 4))
                .foregroundStyle(lineColor.opacity(0.3))
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(lineColor.opacity(0.15))
            .frame(height: 0.5)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            // Certificate number
            Text(certificateNumber)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)

            // Gold badge icon
            Image(systemName: "medal.star.fill")
                .font(.system(size: 48))
                .foregroundStyle(BadgeTier.gold.color)
                .shadow(color: BadgeTier.gold.color.opacity(0.4), radius: 8, y: 2)

            // Title block
            VStack(spacing: 4) {
                Text(String(
                    localized: "Certificate of Completion",
                    comment: "Certificate: formal subtitle"
                ))
                .font(.system(.caption, design: .serif))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(2)

                Text(String(localized: "Line Completed!", comment: "Certificate: main title"))
                    .font(.system(.title2, design: .serif, weight: .bold))
            }

            // "Presented to" + line badge
            VStack(spacing: 8) {
                Text(String(
                    localized: "Awarded for",
                    comment: "Certificate: formal award label"
                ))
                .font(.system(.caption, design: .serif))
                .foregroundStyle(.tertiary)
                .italic()

                // Line badge pill
                Text(data.lineShortName)
                    .font(.title3.bold())
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(lineColor, in: RoundedRectangle(cornerRadius: 6))

                if data.lineLongName != data.lineShortName {
                    Text(data.lineLongName)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Mode label
                Label(data.mode.label, systemImage: data.mode.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCell(
                icon: "mappin.circle.fill",
                value: "\(data.totalStations)",
                label: String(localized: "Stations", comment: "Certificate: stations label")
            )
            statCell(
                icon: "figure.walk",
                value: "\(data.travelCount)",
                label: String(localized: "Travels", comment: "Certificate: travels label")
            )
            statCell(
                icon: "calendar",
                value: data.firstTravelDate.formatted(.dateTime.month(.abbreviated).day().year()),
                label: String(localized: "First Travel", comment: "Certificate: first travel date label")
            )
            statCell(
                icon: "clock.fill",
                value: duration,
                label: String(localized: "Time to Complete", comment: "Certificate: duration label")
            )
        }
    }

    private func statCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(lineColor)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(data.completionDate, format: .dateTime.month(.wide).day().year())
                    .font(.system(.caption, design: .serif, weight: .medium))
                Text(String(
                    localized: "Level \(data.playerLevel)",
                    comment: "Certificate: player level at completion"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(localized: "Métropolist", comment: "Certificate: app name branding"))
                .font(.system(.caption, design: .serif))
                .italic()
                .foregroundStyle(.tertiary)
        }
    }
}
