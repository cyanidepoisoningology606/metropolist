import MapKit
import SwiftUI
import TransitModels

struct TravelDetailView: View {
    @Environment(DataStore.self) private var dataStore
    let travelID: String

    @State private var travel: Travel?
    @State private var line: TransitLine?
    @State private var routeVariant: TransitRouteVariant?
    @State private var journeyStops: [TransitLineStop] = []
    @State private var stationNames: [String: String] = [:]
    @State private var completedStopIDs: Set<String> = []
    @State private var mapSegment: [CLLocationCoordinate2D] = []
    @State private var mapAnnotations: [LineRouteMapView.StationAnnotation] = []
    @State private var travelDistance: Double?
    @AppStorage("mapStyle") private var mapStyle: String = "standard"
    @AppStorage("devMode") private var devMode: Bool = false

    private var mode: TransitMode? {
        line.flatMap { TransitMode(rawValue: $0.mode) }
    }

    private var lineColor: Color {
        line.map { Color(hex: $0.color) } ?? .secondary
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let travel {
                    headerCard(travel, line: line)

                    if !mapAnnotations.isEmpty {
                        LineRouteMapView(
                            segments: mapSegment.count >= 2 ? [mapSegment] : [],
                            stationAnnotations: mapAnnotations,
                            lineColor: lineColor,
                            preferredMapStyle: mapStyle
                        )
                    }

                    journeyCard(travel, line: line)

                    if let line {
                        NavigationLink(value: line.sourceID) {
                            Label(
                                String(localized: "View line", comment: "Travel detail: view line button"),
                                systemImage: "arrow.right.circle"
                            )
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(lineColor, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(Color(hex: line.textColor))
                        }
                    }

                    if devMode {
                        DebugInfoSection(items: [
                            ("travel.id", travel.id),
                            ("lineSourceID", travel.lineSourceID),
                            ("routeVariantSourceID", travel.routeVariantSourceID),
                            ("fromStationSourceID", travel.fromStationSourceID),
                            ("toStationSourceID", travel.toStationSourceID),
                            ("stopsCompleted", String(travel.stopsCompleted)),
                            ("createdAt", travel.createdAt.formatted(.iso8601)),
                            ("line.sourceID", line?.sourceID ?? "nil"),
                            ("routeVariant.sourceID", routeVariant?.sourceID ?? "nil"),
                            ("journeyStops.count", String(journeyStops.count)),
                        ])
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 80)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "Travel Details", comment: "Travel detail: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadData()
        }
    }

    // MARK: - Header Card

    private func headerCard(_ travel: Travel, line: TransitLine?) -> some View {
        CardSection {
            VStack(spacing: 12) {
                // Top accent bar
                lineColor
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .clipShape(Capsule())

                // Mode label
                if let mode {
                    Text(mode.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                if let line {
                    LineBadge(line: line)
                        .scaleEffect(1.5)
                } else {
                    Text(String(localized: "Line no longer exists", comment: "Travel detail: line deleted fallback text"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                // Direction
                if let routeVariant {
                    Text(routeVariant.headsign)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Stats row
                FlowLayout(spacing: 12) {
                    Label(
                        String(localized: "\(travel.stopsCompleted) stops", comment: "Travel detail: stops traveled count"),
                        systemImage: "mappin.and.ellipse"
                    )

                    if let travelDistance, travelDistance > 0 {
                        Label(
                            DistanceCalculator.formatDistance(travelDistance),
                            systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"
                        )
                    }

                    Label {
                        Text(travel.createdAt, format: .dateTime.month(.abbreviated).day().year())
                    } icon: {
                        Image(systemName: "calendar")
                    }

                    Label {
                        Text(travel.createdAt, format: .dateTime.hour().minute())
                    } icon: {
                        Image(systemName: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            var parts: [String] = []
            if let mode { parts.append(mode.label) }
            if let line { parts.append(line.shortName) }
            if let routeVariant { parts.append(routeVariant.headsign) }
            parts.append(String(
                localized: "\(travel.stopsCompleted) stops",
                comment: "Travel detail accessibility: stops count"
            ))
            parts.append(travel.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
            return parts.joined(separator: ", ")
        }())
    }

    // MARK: - Journey Card

    private func journeyCard(_ travel: Travel, line _: TransitLine?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Journey", comment: "Travel detail: journey section header"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVStack(spacing: 0) {
                if journeyStops.isEmpty {
                    simpleItinerary(travel, line: line)
                } else {
                    ForEach(Array(journeyStops.enumerated()), id: \.element.order) { index, stop in
                        let isEndpoint = stop.stationSourceID == travel.fromStationSourceID
                            || stop.stationSourceID == travel.toStationSourceID
                        let isFirst = index == 0
                        let isLast = index == journeyStops.count - 1
                        let name = stationNames[stop.stationSourceID] ?? stop.stationSourceID

                        NavigationLink(value: StationDestination(stationSourceID: stop.stationSourceID)) {
                            HStack(spacing: 12) {
                                ZStack {
                                    VStack(spacing: 0) {
                                        Rectangle()
                                            .fill(isFirst ? .clear : lineColor)
                                            .frame(width: 3)
                                        Rectangle()
                                            .fill(isLast ? .clear : lineColor)
                                            .frame(width: 3)
                                    }

                                    Circle()
                                        .fill(isEndpoint ? lineColor : lineColor.opacity(0.3))
                                        .frame(width: isEndpoint ? 12 : 6, height: isEndpoint ? 12 : 6)
                                        .overlay {
                                            if isEndpoint {
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 2)
                                            }
                                        }
                                }
                                .frame(width: 20)

                                Text(name)
                                    .font(isEndpoint ? .subheadline.weight(.semibold) : .subheadline)
                                    .foregroundStyle(isEndpoint ? .primary : .secondary)

                                Spacer()

                                if completedStopIDs.contains(stop.stationSourceID) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(height: isEndpoint ? 36 : 28)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func simpleItinerary(_ travel: Travel, line _: TransitLine?) -> some View {
        let fromName = stationNames[travel.fromStationSourceID] ?? travel.fromStationSourceID
        let toName = stationNames[travel.toStationSourceID] ?? travel.toStationSourceID

        VStack(spacing: 0) {
            NavigationLink(value: StationDestination(stationSourceID: travel.fromStationSourceID)) {
                HStack(spacing: 12) {
                    ZStack {
                        VStack(spacing: 0) {
                            Rectangle().fill(.clear).frame(width: 3)
                            Rectangle().fill(lineColor).frame(width: 3)
                        }
                        Circle().fill(lineColor).frame(width: 12, height: 12)
                            .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
                    }
                    .frame(width: 20)

                    Text(fromName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 36)
            }
            .buttonStyle(.plain)

            if travel.stopsCompleted > 2 {
                HStack(spacing: 12) {
                    ZStack {
                        Rectangle().fill(lineColor).frame(width: 3)
                        Circle().fill(lineColor.opacity(0.3)).frame(width: 6, height: 6)
                    }
                    .frame(width: 20)

                    Text(String(
                        localized: "\(travel.stopsCompleted - 2) intermediate stops",
                        comment: "Travel detail: intermediate stops count"
                    ))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(height: 24)
            }

            NavigationLink(value: StationDestination(stationSourceID: travel.toStationSourceID)) {
                HStack(spacing: 12) {
                    ZStack {
                        VStack(spacing: 0) {
                            Rectangle().fill(lineColor).frame(width: 3)
                            Rectangle().fill(.clear).frame(width: 3)
                        }
                        Circle().fill(lineColor).frame(width: 12, height: 12)
                            .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
                    }
                    .frame(width: 20)

                    Text(toName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 36)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        do {
            guard let travel = try dataStore.userService.travel(byID: travelID) else { return }
            self.travel = travel

            line = try dataStore.transitService.line(bySourceID: travel.lineSourceID)

            // Load station names
            let stationIDs = [travel.fromStationSourceID, travel.toStationSourceID]
            let stations = try dataStore.transitService.stations(bySourceIDs: stationIDs)
            var names: [String: String] = [:]
            for station in stations {
                names[station.sourceID] = station.name
            }

            // Load route variant and journey stops
            let variants = try dataStore.transitService.routeVariants(forLineSourceID: travel.lineSourceID)
            if let variant = variants.first(where: { $0.sourceID == travel.routeVariantSourceID }) {
                routeVariant = variant

                let allStops = try dataStore.transitService.lineStops(forRouteVariantSourceID: variant.sourceID)
                if let fromOrder = allStops.order(of: travel.fromStationSourceID) {
                    let resolvedToOrder: Int? = if let forward = allStops.order(of: travel.toStationSourceID, after: fromOrder) {
                        forward
                    } else {
                        allStops.order(of: travel.toStationSourceID, before: fromOrder)
                    }
                    if let toOrder = resolvedToOrder {
                        let lower = min(fromOrder, toOrder)
                        let upper = max(fromOrder, toOrder)
                        journeyStops = try dataStore.transitService.intermediateStops(
                            routeVariantSourceID: variant.sourceID,
                            fromOrder: lower,
                            toOrder: upper
                        )
                        if fromOrder > toOrder { journeyStops.reverse() }

                        // Load names for all journey stops
                        let journeyStationIDs = journeyStops.map(\.stationSourceID)
                        let journeyStations = try dataStore.transitService.stations(bySourceIDs: journeyStationIDs)
                        for station in journeyStations {
                            names[station.sourceID] = station.name
                        }
                    }
                }
            }

            // Fill missing station names with fallback
            for id in [travel.fromStationSourceID, travel.toStationSourceID] where names[id] == nil {
                names[id] = String(localized: "Unknown stop", comment: "Travel detail: fallback name for missing stop")
            }
            stationNames = names

            // Build map data from journey stops
            let mapData = try buildMapData(
                travel: travel,
                journeyStops: journeyStops,
                stationNames: names,
                transitService: dataStore.transitService
            )
            mapSegment = mapData.segment
            mapAnnotations = mapData.annotations

            travelDistance = logged("travelDistance") {
                try DistanceCalculator.distance(for: travel, transitService: dataStore.transitService)
            } ?? nil

            // Load completed stops for this line
            completedStopIDs = try dataStore.userService.completedStopIDs(forLineSourceID: travel.lineSourceID)
        } catch {
            #if DEBUG
                print("Failed to load travel detail: \(error)")
            #endif
        }
    }
}
