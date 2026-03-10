import SwiftUI

struct LicencesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                odblSection
                etalabSection
                mobilitesSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(localized: "Open Data Licences", comment: "Licences: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: ODbL datasets

    private var odblSection: some View {
        CardSection(title: String(localized: "OPEN DATABASE LICENCE (ODbL)", comment: "Licences: ODbL section header")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(
                    // swiftlint:disable:next line_length
                    localized: "Contains information from the following databases by Île-de-France Mobilités, made available under the Open Database Licence (ODbL).",
                    comment: "Licences: ODbL attribution text"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                if let url = URL(string: "https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/arrets-lignes") {
                    datasetLink(name: "Arrêts-lignes", url: url)
                }

                Divider()

                if let url = URL(string: "https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/referentiel-des-lignes") {
                    datasetLink(name: "Référentiel des lignes", url: url)
                }

                Divider()

                if let url = URL(string: "https://opendatacommons.org/licenses/odbl/1-0/") {
                    licenceLink(label: "Open Database Licence (ODbL)", url: url)
                }
            }
        }
    }

    // MARK: Etalab dataset

    private var etalabSection: some View {
        CardSection(title: String(localized: "LICENCE OUVERTE v2.0 (ETALAB)", comment: "Licences: Etalab section header")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(
                    // swiftlint:disable:next line_length
                    localized: "Contains information from the following dataset by Île-de-France Mobilités, made available under Licence Ouverte v2.0 (Etalab).",
                    comment: "Licences: Etalab attribution text"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                if let url = URL(string: "https://prim.iledefrance-mobilites.fr/fr/jeux-de-donnees/arrets") {
                    datasetLink(name: "Arrêts", url: url)
                }

                Divider()

                if let url = URL(string: "https://www.etalab.gouv.fr/licence-ouverte-open-licence") {
                    licenceLink(label: "Licence Ouverte v2.0", url: url)
                }
            }
        }
    }

    // MARK: Licence Mobilités dataset

    private var mobilitesSection: some View {
        CardSection(title: String(localized: "LICENCE MOBILITÉS", comment: "Licences: Licence Mobilités section header")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(
                    localized: "Contains information from the following dataset, made available under the Licence Mobilités.",
                    comment: "Licences: Licence Mobilités attribution text"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                // swiftlint:disable:next line_length
                if let url = URL(string: "https://www.data.gouv.fr/datasets/horaires-prevus-sur-les-lignes-de-transport-en-commun-dile-de-france-gtfs-datahub") {
                    datasetLink(name: "GTFS Horaires", url: url)
                }

                Divider()

                if let url = URL(string: "https://cloud.fabmob.io/s/eYWWJBdM3fQiFNm") {
                    licenceLink(label: "Licence Mobilités", url: url)
                }
            }
        }
    }

    // MARK: Helpers

    private func datasetLink(name: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(name)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    private func licenceLink(label: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
            }
        }
    }
}
