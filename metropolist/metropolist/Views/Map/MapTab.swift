import MapKit
import SwiftUI
import TransitModels

struct MapTab: View {
    @Environment(DataStore.self) private var dataStore
    @State private var spatialIndex: SpatialIndex?
    @State private var visitedStationIDs: Set<String> = []
    @State private var stationNames: [String: String] = [:]
    @State private var stationCoordinates: [String: CLLocationCoordinate2D] = [:]
    @State private var stationModes: [String: Set<TransitMode>] = [:]
    @State private var availableModes: [TransitMode] = []
    @State private var selectedModes: Set<TransitMode> = []
    @State private var visitFilter: StationVisitFilter = .all
    @State private var filterVersion = 0
    @State private var compassButton: MKCompassButton?
    @State private var userTrackingButton: MKUserTrackingButton?
    @State private var path = NavigationPath()
    @State private var selectedStation: MapStationSelection?
    @State private var popoverLines: [TransitLine] = []
    @AppStorage("mapStyle") private var mapStylePreference = "standard"
    @State private var fitRegion: MKCoordinateRegion?
    @State private var showFilter = false
    @State private var isHeatmapMode = false
    @State private var heatmapOverlay: HeatmapOverlay?
    @State private var indexError = false

    private var isFilterActive: Bool {
        selectedModes != Set(availableModes) || visitFilter != .all
    }

    private var filteredStationIDs: Set<String>? {
        guard isFilterActive else { return nil }

        let allModesSelected = selectedModes == Set(availableModes)
        var result: Set<String>

        if allModesSelected {
            result = Set(stationNames.keys)
        } else {
            result = []
            for (stationID, modes) in stationModes {
                guard !modes.isDisjoint(with: selectedModes) else { continue }
                result.insert(stationID)
            }
        }

        switch visitFilter {
        case .all: break
        case .visited:
            result = result.intersection(visitedStationIDs)
        case .unvisited:
            result = result.subtracting(visitedStationIDs)
        }

        return result
    }

    var body: some View {
        let filtered = filteredStationIDs
        let visibleCount = filtered?.count ?? stationNames.count
        let visitedVisible = if let filtered {
            filtered.intersection(visitedStationIDs).count
        } else {
            visitedStationIDs.count
        }

        return NavigationStack(path: $path) {
            mapContent(filtered: filtered, visibleCount: visibleCount, visitedVisible: visitedVisible)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: StationDestination.self) { dest in
                    StationDetailView(stationSourceID: dest.stationSourceID)
                }
                .task {
                    await buildIndex()
                }
                .onChange(of: dataStore.userDataVersion) {
                    refreshVisited()
                    rebuildHeatmapIfNeeded()
                    filterVersion += 1
                }
                .onChange(of: selectedModes) { oldValue, _ in
                    guard !oldValue.isEmpty else { return }
                    filterVersion += 1
                }
                .onChange(of: visitFilter) { _, _ in filterVersion += 1 }
                .onChange(of: isHeatmapMode) { _, _ in rebuildHeatmapIfNeeded() }
                .onChange(of: selectedStation) { _, newValue in
                    if let station = newValue {
                        loadPopoverLines(for: station.sourceID)
                    } else {
                        popoverLines = []
                    }
                }
        }
    }

    private func mapContent(
        filtered: Set<String>?,
        visibleCount: Int,
        visitedVisible: Int
    ) -> some View {
        ZStack {
            if let spatialIndex {
                StationMapView(
                    spatialIndex: spatialIndex,
                    visitedStationIDs: visitedStationIDs,
                    filteredStationIDs: filtered,
                    stationNames: stationNames,
                    stationCoordinates: stationCoordinates,
                    filterVersion: filterVersion,
                    mapStyle: mapStylePreference,
                    initialRegion: spatialIndex.boundingRegion,
                    heatmapOverlay: heatmapOverlay,
                    fitRegion: $fitRegion,
                    fitEdgePadding: UIEdgeInsets(top: 60, left: 20, bottom: 100, right: 60),
                    selectedStation: $selectedStation,
                    onMapTapped: {
                        withAnimation(.spring(duration: 0.3)) {
                            showFilter = false
                        }
                    },
                    onMapControls: { compass, tracking in
                        compassButton = compass
                        userTrackingButton = tracking
                    }
                )
                .ignoresSafeArea()
            } else if indexError {
                indexErrorView
            } else {
                TransitLoadingIndicator()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .bottom) {
            if let station = selectedStation {
                StationPopoverCard(
                    station: station,
                    lines: popoverLines,
                    onDetails: {
                        selectedStation = nil
                        path.append(StationDestination(stationSourceID: station.sourceID))
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 82)
            }
        }
        .overlay(alignment: .topLeading) {
            if spatialIndex != nil {
                visitedCountBadge(visited: visitedVisible, total: visibleCount)
                    .padding(.top, 10)
                    .padding(.leading, 12)
            }
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 12) {
                heatmapToggle
                if !isHeatmapMode {
                    filterButton
                    filterPanel
                }
                fitToMapButton

                if let userTrackingButton {
                    MapControlWrapper(view: userTrackingButton)
                        .frame(width: 44, height: 44)
                }
                if let compassButton {
                    MapControlWrapper(view: compassButton)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.top, 10)
            .padding(.trailing, 12)
        }
    }

    private var indexErrorView: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                String(localized: "Unable to Load Map", comment: "Map tab: error title when station data fails to load"),
                systemImage: "map.fill",
                description: Text("An error occurred while loading station data.",
                                  comment: "Map tab: error description when station data fails to load")
            )
            .symbolEffect(.pulse)
            Button(String(localized: "Retry", comment: "Map tab: button to retry loading station data")) {
                Task { await buildIndex() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                showFilter.toggle()
            }
        } label: {
            Image(systemName: isFilterActive
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
                .font(.title2)
                .padding(10)
        }
        .mapButtonStyle()
        .accessibilityLabel(String(localized: "Filter stations", comment: "Map accessibility: filter button"))
        .accessibilityValue(isFilterActive
            ? String(localized: "Active", comment: "Map accessibility: filter active")
            : String(localized: "Inactive", comment: "Map accessibility: filter inactive"))
    }

    @ViewBuilder
    private var filterPanel: some View {
        if showFilter {
            MapFilterPanel(
                visitFilter: $visitFilter,
                selectedModes: $selectedModes,
                availableModes: availableModes
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
        }
    }

    private var fitToMapButton: some View {
        Button {
            guard let spatialIndex else { return }
            if let filtered = filteredStationIDs {
                fitRegion = spatialIndex.boundingRegion(for: filtered)
            } else {
                fitRegion = spatialIndex.boundingRegion
            }
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.title2)
                .padding(10)
        }
        .mapButtonStyle()
        .accessibilityLabel(String(localized: "Fit to map", comment: "Map accessibility: fit to map button"))
    }

    private func visitedCountBadge(visited: Int, total: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "tram.fill")
                .font(.subheadline)
            Text("\(visited)/\(total)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .mapPillStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            localized: "Visited \(visited) of \(total) stops",
            comment: "Map accessibility: visited count badge"
        ))
    }

    private var heatmapToggle: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                isHeatmapMode.toggle()
                showFilter = false
            }
        } label: {
            Image(systemName: isHeatmapMode ? "flame.fill" : "flame")
                .font(.title2)
                .foregroundStyle(isHeatmapMode ? .red : .primary)
                .padding(10)
        }
        .mapButtonStyle()
        .accessibilityLabel(String(localized: "Heatmap", comment: "Map accessibility: heatmap toggle"))
        .accessibilityValue(isHeatmapMode
            ? String(localized: "On", comment: "Map accessibility: heatmap on")
            : String(localized: "Off", comment: "Map accessibility: heatmap off"))
        .accessibilityAddTraits(.isToggle)
    }

    // MARK: - Heatmap

    private func rebuildHeatmapIfNeeded() {
        guard isHeatmapMode else {
            heatmapOverlay = nil
            return
        }
        let travels = (try? dataStore.userService.allTravels()) ?? []
        let stops = (try? dataStore.userService.allCompletedStops()) ?? []
        let points = VisitFrequencyCalculator.compute(
            travels: travels,
            completedStops: stops,
            coordinates: stationCoordinates
        )
        heatmapOverlay = points.isEmpty ? nil : HeatmapOverlay(heatPoints: points)
    }

    // MARK: - Data Loading

    private func buildIndex() async {
        indexError = false
        let transitService = dataStore.transitService
        let stations: [TransitStation]
        do {
            stations = try transitService.allStations()
        } catch {
            indexError = true
            return
        }

        let points = stations.map { station in
            IndexedPoint(
                sourceID: station.sourceID,
                lng: station.longitude,
                lat: station.latitude,
                name: station.name
            )
        }

        let names = Dictionary(uniqueKeysWithValues: stations.map { ($0.sourceID, $0.name) })
        let coordinates = Dictionary(uniqueKeysWithValues: stations.map {
            ($0.sourceID, CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))
        })

        let index = await Task.detached {
            SpatialIndex(points: points)
        }.value

        let modes: [String: Set<TransitMode>]
        do {
            let rawModes = try dataStore.modesByStation()
            modes = rawModes.reduce(into: [:]) { result, entry in
                result[entry.key] = Set(entry.value.compactMap { TransitMode(rawValue: $0) })
            }
        } catch {
            modes = [:]
        }

        let available = Set(modes.values.flatMap(\.self))
            .sorted { $0.sortOrder < $1.sortOrder }

        spatialIndex = index
        stationNames = names
        stationCoordinates = coordinates
        stationModes = modes
        availableModes = available
        selectedModes = Set(available)
        refreshVisited()
    }

    private func loadPopoverLines(for stationSourceID: String) {
        popoverLines = logged {
            try dataStore.transitService.lines(forStationSourceID: stationSourceID)
        } ?? []
    }

    private func refreshVisited() {
        do {
            let stops = try dataStore.userService.allCompletedStops()
            visitedStationIDs = Set(stops.map(\.stationSourceID))
        } catch {
            visitedStationIDs = []
        }
    }
}
