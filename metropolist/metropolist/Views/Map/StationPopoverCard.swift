import SwiftUI
import TransitModels

struct StationPopoverCard: View {
    let station: MapStationSelection
    let lines: [TransitLine]
    let onDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(station.name)
                .font(.headline)
                .lineLimit(1)

            if !lines.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(lines) { line in
                            LineBadge(line: line)
                        }
                    }
                }
            }

            Button {
                onDetails()
            } label: {
                Text(String(localized: "Details", comment: "Station popover: navigate to station detail"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .mapCardStyle()
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(
            localized: "\(station.name) station",
            comment: "Station popover accessibility: station name"
        ))
    }
}
