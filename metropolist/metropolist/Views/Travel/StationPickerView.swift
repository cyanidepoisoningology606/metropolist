import SwiftUI
import TransitModels

struct StationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TravelFlowViewModel

    @State private var searchText = ""
    @State private var searchResults: [TransitStation] = []
    @State private var loadedLines: [String: [TransitLine]] = [:]
    @State private var lastSearchedQuery = ""
    @AppStorage("destinationSort") private var destinationSort: String = "route"

    private var hasLinePrefill: Bool {
        viewModel.prefill?.lineSourceID != nil
    }

    private var sortedLineStations: [TransitStation] {
        if destinationSort == "alphabetical" {
            viewModel.prefillLineStations.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } else {
            viewModel.prefillLineStations
        }
    }

    var body: some View {
        List {
            if searchText.isEmpty {
                if hasLinePrefill {
                    lineStopsSection
                } else if viewModel.isLoadingNearby {
                    Section {
                        HStack(spacing: 12) {
                            TransitLoadingIndicator()
                            Text(String(localized: "Finding nearby stops...", comment: "Stop picker: nearby stops loading"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    }
                } else if !viewModel.nearbyStations.isEmpty {
                    Section(String(localized: "Nearby", comment: "Stop picker: nearby stops section header")) {
                        ForEach(viewModel.nearbyStations) { nearby in
                            Button {
                                viewModel.selectOrigin(nearby.station)
                            } label: {
                                nearbyStationRow(nearby)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        String(localized: "Search for a stop", comment: "Stop picker: empty state title"),
                        systemImage: "magnifyingglass",
                        description: Text(String(
                            localized: "Type a stop name to get started",
                            comment: "Stop picker: empty state description"
                        ))
                    )
                }
            } else {
                Section {
                    if searchResults.isEmpty {
                        if searchText == lastSearchedQuery {
                            ContentUnavailableView.search(text: searchText)
                        } else {
                            TransitLoadingIndicator()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }
                    } else {
                        ForEach(searchResults) { station in
                            Button {
                                viewModel.selectOrigin(station)
                            } label: {
                                searchResultRow(station)
                            }
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text(String(localized: "Results (\(searchResults.count))", comment: "Station picker: search results count header"))
                        if searchText != lastSearchedQuery {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .navigationTitle(String(localized: "Departure", comment: "Station picker: navigation title"))
        .searchable(text: $searchText, prompt: String(localized: "Stop name", comment: "Stop picker: search field prompt"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
            }
            if hasLinePrefill {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(String(localized: "Sort", comment: "Station picker: sort order picker label"), selection: $destinationSort) {
                            Text(String(localized: "Route Order", comment: "Settings: sort by route order")).tag("route")
                            Text(String(localized: "Alphabetical", comment: "Settings: sort alphabetically")).tag("alphabetical")
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refreshNearbyStations()
                    } label: {
                        Image(systemName: "location.fill")
                    }
                    .disabled(viewModel.isLoadingNearby)
                }
            }
        }
        .task(id: searchText) {
            let query = searchText
            guard !query.isEmpty else {
                searchResults = []
                lastSearchedQuery = ""
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = viewModel.searchStations(query: query)
            guard !Task.isCancelled else { return }
            searchResults = results
            lastSearchedQuery = query

            // Batch-load lines for all search results
            let stationIDs = Set(results.map(\.sourceID))
                .subtracting(loadedLines.keys)
            if !stationIDs.isEmpty {
                let batchLines = viewModel.linesForStations(stationIDs)
                for (id, lines) in batchLines {
                    loadedLines[id] = lines
                }
                for id in stationIDs where loadedLines[id] == nil {
                    loadedLines[id] = []
                }
            }
        }
        .task {
            if viewModel.prefill?.stationSourceID != nil {
                viewModel.autoSelectOriginFromPrefill()
            } else if hasLinePrefill {
                await viewModel.loadLineStations()
            } else {
                viewModel.loadNearbyStations()
            }
        }
    }

    // MARK: - Line Stops Section

    @ViewBuilder
    private var lineStopsSection: some View {
        if viewModel.isLoadingLineStations {
            Section {
                HStack(spacing: 12) {
                    TransitLoadingIndicator()
                    Text(String(localized: "Loading stops...", comment: "Station picker: loading line stops indicator"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        } else if !sortedLineStations.isEmpty {
            Section {
                ForEach(sortedLineStations) { station in
                    Button {
                        viewModel.selectOrigin(station)
                    } label: {
                        lineStopRow(station)
                    }
                }
            } header: {
                if let line = viewModel.prefillLine {
                    HStack(spacing: 8) {
                        LineBadge(line: line)
                        Text(String(localized: "Stops", comment: "Station picker: line stops section header"))
                    }
                }
            }
        }
    }

    // MARK: - Row Views

    private func lineStopRow(_ station: TransitStation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(station.name)
                .font(.body)
                .foregroundStyle(.primary)
            if let town = station.town {
                Text(town)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(station.town.map { "\(station.name), \($0)" } ?? station.name)
        .accessibilityHint(String(localized: "Select as departure stop", comment: "Station picker accessibility: line stop hint"))
    }

    private func nearbyStationRow(_ nearby: TravelFlowViewModel.NearbyStation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(nearby.station.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(DistanceCalculator.formatDistance(nearby.distance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let town = nearby.station.town {
                Text(town)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !nearby.lines.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(nearby.lines) { line in
                            LineBadge(line: line)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [
                nearby.station.name,
                nearby.station.town,
                DistanceCalculator.formatDistance(nearby.distance),
            ]
            .compactMap(\.self)
            .joined(separator: ", ")
        )
        .accessibilityHint(String(localized: "Select as departure stop", comment: "Station picker accessibility: nearby stop hint"))
    }

    private func searchResultRow(_ station: TransitStation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(station.name)
                .font(.body)
                .foregroundStyle(.primary)
            if let town = station.town {
                Text(town)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let lines = loadedLines[station.sourceID] {
                if !lines.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(lines) { line in
                                LineBadge(line: line)
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(station.town.map { "\(station.name), \($0)" } ?? station.name)
        .accessibilityHint(String(localized: "Select as departure stop", comment: "Station picker accessibility: search result hint"))
    }
}
