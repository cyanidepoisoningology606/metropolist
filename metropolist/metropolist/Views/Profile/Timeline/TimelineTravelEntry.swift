import SwiftUI
import TransitModels

struct TimelineTravelEntry: View {
    let travel: Travel
    let line: TransitLine?
    let fromName: String
    let toName: String
    let isFirst: Bool
    let isLast: Bool
    let isHighlighted: Bool

    private var mode: TransitMode? {
        line.flatMap { TransitMode(rawValue: $0.mode) }
    }

    private var lineColor: Color {
        line.map { Color(hex: $0.color) } ?? .secondary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timeColumn
            connectorColumn
            travelCard
        }
        .padding(.bottom, isLast ? 0 : 8)
    }

    // MARK: - Time

    private var timeColumn: some View {
        Text(travel.createdAt, format: .dateTime.hour().minute())
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 44, alignment: .trailing)
            .padding(.top, 6)
    }

    // MARK: - Connector

    private var connectorColumn: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? .clear : .secondary.opacity(0.3))
                .frame(width: 2, height: 12)

            ZStack {
                Circle()
                    .fill(lineColor)
                    .frame(width: 28, height: 28)

                Image(systemName: mode?.systemImage ?? "tram.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Rectangle()
                .fill(isLast ? .clear : .secondary.opacity(0.3))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 28)
    }

    // MARK: - Card

    private var travelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let line {
                    LineBadge(line: line)
                }
                if let mode {
                    Text(mode.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 2) {
                    Circle()
                        .fill(lineColor)
                        .frame(width: 6, height: 6)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(lineColor.opacity(0.4))
                        .frame(width: 2, height: 16)
                    Circle()
                        .fill(lineColor)
                        .frame(width: 6, height: 6)
                }
                .padding(.top, 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text(fromName)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(toName)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }

            Label(
                String(localized: "\(travel.stopsCompleted) stops", comment: "Timeline: stops traveled count"),
                systemImage: "mappin.and.ellipse"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(lineColor, lineWidth: 2)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }
}
