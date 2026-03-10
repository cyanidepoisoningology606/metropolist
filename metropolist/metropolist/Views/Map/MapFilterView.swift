import SwiftUI

enum StationVisitFilter: String, CaseIterable {
    case all
    case visited
    case unvisited

    var label: String {
        switch self {
        case .all: String(localized: "All Stations", comment: "Map filter: show all stations")
        case .visited: String(localized: "Visited", comment: "Map filter: visited only")
        case .unvisited: String(localized: "Unvisited", comment: "Map filter: unvisited only")
        }
    }
}

struct MapFilterPanel: View {
    @Binding var visitFilter: StationVisitFilter
    @Binding var selectedModes: Set<TransitMode>
    let availableModes: [TransitMode]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(StationVisitFilter.allCases, id: \.self) { filter in
                visitFilterRow(for: filter)
            }

            Divider()
                .padding(.vertical, 4)

            ForEach(availableModes, id: \.self) { mode in
                modeRow(for: mode)
            }

            Divider()
                .padding(.vertical, 4)

            Button {
                selectedModes = Set(availableModes)
                visitFilter = .all
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Reset Filters", comment: "Map filter: reset all"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .contentShape(Rectangle())
        .mapCardStyle()
        .frame(maxWidth: 240)
    }

    private func visitFilterRow(for filter: StationVisitFilter) -> some View {
        let isSelected = visitFilter == filter
        return Button {
            visitFilter = filter
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                Text(filter.label)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func modeRow(for mode: TransitMode) -> some View {
        let isSelected = selectedModes.contains(mode)
        return Button {
            if isSelected {
                if selectedModes.count > 1 {
                    selectedModes.remove(mode)
                }
            } else {
                selectedModes.insert(mode)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: mode.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(mode.tintColor)
                    .frame(width: 20)
                Text(mode.label)
                    .font(.subheadline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(mode.tintColor)
                }
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .opacity(isSelected ? 1 : 0.6)
        }
        .buttonStyle(.plain)
    }
}
