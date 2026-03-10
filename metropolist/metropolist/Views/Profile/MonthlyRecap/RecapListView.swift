import SwiftUI

struct RecapListView: View {
    @State var viewModel: RecapListViewModel
    @State private var selectedRecap: RecapKind?

    private let dataStore: DataStore

    init(dataStore: DataStore) {
        self.dataStore = dataStore
        _viewModel = State(initialValue: RecapListViewModel(dataStore: dataStore))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isEmpty {
                emptyState
            } else {
                recapList
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(localized: "Recaps", comment: "Recap list: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .fullScreenCover(
            item: Binding(
                get: { selectedRecap.map { RecapPresentation(kind: $0) } },
                set: { selectedRecap = $0?.kind }
            ),
            content: { presentation in
                switch presentation.kind {
                case let .monthly(month):
                    MonthlyRecapView(month: month, dataStore: dataStore)
                case let .yearly(year):
                    YearlyRecapView(year: year, dataStore: dataStore)
                }
            }
        )
    }
}

// MARK: - Content

private extension RecapListView {
    var recapList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.groupedByYear, id: \.year) { group in
                    yearSection(group)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
    }

    func yearSection(_ group: YearGroup) -> some View {
        Section {
            ForEach(group.summaries) { summary in
                Button { selectedRecap = summary.kind } label: {
                    if summary.isYearly {
                        YearlyRecapRowCard(summary: summary)
                    } else {
                        MonthlyRecapRowCard(summary: summary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(String(group.year))
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, group.year == viewModel.groupedByYear.first?.year ? 0 : 8)
        }
    }

    var emptyState: some View {
        ContentUnavailableView(
            String(localized: "No recaps yet", comment: "Recap list: empty state title"),
            systemImage: "calendar.badge.clock",
            description: Text(
                String(
                    localized: "Start recording travels to see your progress",
                    comment: "Recap list: empty state description"
                )
            )
        )
    }
}

// MARK: - Monthly Row Card

private struct MonthlyRecapRowCard: View {
    let summary: RecapSummary

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(summary.dominantModeColor)
                .frame(width: 6)

            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("\(summary.travelCount)", comment: "Recap row: travel count for monthly recap")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(summary.dominantModeColor)
                    if let mode = summary.dominantMode {
                        Image(systemName: mode.systemImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.formattedTitle)
                        .font(.headline)
                    Text(rowTagline(summary))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(
                        "\(summary.discoveryCount) new stops \u{00B7} \(summary.activeDays) active days",
                        comment: "Recap row: compact stat line with new stops and active days"
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func rowTagline(_ summary: RecapSummary) -> String {
        if summary.discoveryCount == 0, summary.travelCount > 0 {
            return String(localized: "A creature of habit", comment: "Recap row: shown when no new stops discovered")
        }
        if summary.discoveryCount > 10 {
            return String(
                localized: "You discovered \(summary.discoveryCount) new stops",
                comment: "Recap row: shown when many new stops discovered"
            )
        }
        if summary.activeDays == 1 {
            return String(localized: "A quick visit", comment: "Recap row: shown when only 1 active day")
        }
        return String(
            localized: "\(summary.travelCount) travels, \(summary.discoveryCount) discoveries",
            comment: "Recap row: default summary with travel and discovery counts"
        )
    }
}

// MARK: - Yearly Row Card

private struct YearlyRecapRowCard: View {
    let summary: RecapSummary

    private var gradientColors: [Color] {
        let colors = summary.topModeColors
        guard colors.count >= 2 else {
            return [summary.dominantModeColor, summary.dominantModeColor.opacity(0.6)]
        }
        return colors
    }

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom)
                .frame(width: 6)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("\(summary.travelCount)", comment: "Recap row: travel count for yearly recap")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(summary.dominantModeColor)
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                .frame(width: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.formattedTitle)
                        .font(.headline)
                    Text(
                        "\(summary.discoveryCount) discoveries \u{00B7} \(summary.activeDays) active days",
                        comment: "Yearly recap row: compact stat line"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
