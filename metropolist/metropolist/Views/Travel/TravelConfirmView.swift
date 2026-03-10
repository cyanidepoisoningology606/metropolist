import SwiftUI
import TransitModels

struct TravelConfirmView: View {
    @Bindable var viewModel: TravelFlowViewModel

    @State private var confirmTrigger = false

    private var newStopsCount: Int {
        let completed = viewModel.completedStopIDsForLine
        return viewModel.intermediateStops
            .filter { stop in
                !completed.contains(stop.stationSourceID)
            }
            .count
    }

    var body: some View {
        List {
            if let line = viewModel.selectedLine, let variant = viewModel.selectedVariant {
                Section {
                    HStack {
                        LineBadge(line: line)
                        Text(variant.headsign)
                            .font(.subheadline)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(
                        localized: "Line \(line.shortName), direction \(variant.headsign)",
                        comment: "Travel confirm accessibility: line and direction"
                    ))
                }

                Section {
                    let lineColor = Color(hex: line.color)
                    let stops = viewModel.intermediateStops
                    let completed = viewModel.completedStopIDsForLine

                    VStack(spacing: 0) {
                        ForEach(Array(stops.enumerated()), id: \.element.order) { index, stop in
                            let isEndpoint = stop.stationSourceID == viewModel.originStation?.sourceID
                                || stop.stationSourceID == viewModel.destinationStation?.sourceID
                            let isFirst = index == 0
                            let isLast = index == stops.count - 1
                            let isCompleted = completed.contains(stop.stationSourceID)

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

                                Text(viewModel.intermediateStationNames[stop.stationSourceID] ?? stop.stationSourceID)
                                    .font(isEndpoint ? .subheadline.weight(.semibold) : .subheadline)
                                    .foregroundStyle(isEndpoint ? .primary : .secondary)

                                Spacer()

                                if !isCompleted {
                                    Text(String(localized: "NEW", comment: "Travel confirm: new stop badge"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(lineColor)
                                }
                            }
                            .frame(height: isEndpoint ? 36 : 28)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                [
                                    viewModel.intermediateStationNames[stop.stationSourceID] ?? stop.stationSourceID,
                                    isEndpoint
                                        ? String(localized: "endpoint", comment: "Travel confirm accessibility: endpoint marker")
                                        : nil,
                                    !isCompleted
                                        ? String(localized: "new stop", comment: "Travel confirm accessibility: new stop marker")
                                        : nil,
                                ]
                                .compactMap(\.self)
                                .joined(separator: ", ")
                            )
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                } header: {
                    if newStopsCount > 0 {
                        Text(String(
                            localized: "Your journey · \(newStopsCount) new stops",
                            comment: "Travel confirm: journey section header with new stops count"
                        ))
                    } else {
                        Text(String(localized: "Your journey", comment: "Travel confirm: journey stops section header"))
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                confirmTrigger.toggle()
                viewModel.confirmTravel()
            } label: {
                Group {
                    if viewModel.isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(localized: "Confirm journey", comment: "Travel confirm: confirm button label"))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(viewModel.isProcessing)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
            .accessibilityIdentifier("button-confirm-travel")
            .sensoryFeedback(.success, trigger: confirmTrigger)
        }
        .navigationTitle(String(localized: "Confirm travel", comment: "Travel confirm: navigation title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                DatePicker(
                    String(localized: "Travel date", comment: "Travel confirm: date picker accessibility label"),
                    selection: $viewModel.travelDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
            }
        }
    }
}
