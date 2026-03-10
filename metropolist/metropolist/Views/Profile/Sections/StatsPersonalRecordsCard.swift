import SwiftUI

struct PersonalRecordsCard: View {
    let records: PersonalRecords

    var body: some View {
        CardSection(title: String(localized: "PERSONAL RECORDS", comment: "Statistics: personal records section header")) {
            if records.isEmpty {
                Text(String(localized: "Keep exploring to set records!", comment: "Statistics: empty personal records"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    if let record = records.mostTravelsInDay {
                        RecordRow(
                            icon: "figure.walk",
                            tint: .metroSignature,
                            title: String(localized: "Most travels in a day", comment: "Statistics: most travels record title"),
                            value: "\(record.count)",
                            detail: record.date.formatted(.dateTime.month(.wide).day().year())
                        )
                    }

                    if let record = records.mostDiscoveriesInDay {
                        RecordRow(
                            icon: "mappin.and.ellipse",
                            tint: .green,
                            title: String(localized: "Most discoveries in a day", comment: "Statistics: most discoveries record title"),
                            value: "\(record.count)",
                            detail: record.date.formatted(.dateTime.month(.wide).day().year())
                        )
                    }

                    if let record = records.mostModesInDay {
                        MostModesRow(record: record)
                    }

                    if let record = records.mostDistanceInDay {
                        RecordRow(
                            icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                            tint: .mint,
                            title: String(localized: "Most distance in a day", comment: "Statistics: most distance record title"),
                            value: DistanceCalculator.formatDistance(record.distance),
                            detail: record.date.formatted(.dateTime.month(.wide).day().year())
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Record Row

private struct RecordRow: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Most Modes Row

private struct MostModesRow: View {
    let record: MostModesRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.subheadline)
                .foregroundStyle(.purple)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Most modes in a day", comment: "Statistics: most modes record title"))
                    .font(.subheadline)

                Text(record.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(record.count)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.purple)
        }
    }
}
