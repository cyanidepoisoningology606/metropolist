import SwiftUI

extension SettingsTab {
    // MARK: - About Section

    var aboutSection: some View {
        CardSection(title: String(localized: "ABOUT", comment: "Settings: about section header")) {
            VStack(spacing: 12) {
                HStack {
                    Text(String(localized: "Version", comment: "Settings: app version label"))
                        .font(.subheadline)
                    Spacer()
                    Text(appVersion)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Text(String(localized: "Build", comment: "Settings: build number label"))
                        .font(.subheadline)
                    Spacer()
                    Text(devModeFeedback ?? buildNumber)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    devModeTapCount += 1
                    if devModeTapCount >= 5 {
                        devModeTapCount = 0
                        devMode.toggle()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(reduceMotion ? .none : .default) {
                            devModeFeedback = devMode ? "Developer Mode ON" : "Developer Mode OFF"
                        }
                        devModeFeedbackTask?.cancel()
                        devModeFeedbackTask = Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation(reduceMotion ? .none : .default) {
                                devModeFeedback = nil
                            }
                        }
                    }
                }

                Divider()

                HStack {
                    Text(String(localized: "Data Version", comment: "Settings: transit data version label"))
                        .font(.subheadline)
                    Spacer()
                    Text(dataVersion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                NavigationLink(destination: LicencesView()) {
                    HStack {
                        Text(String(localized: "Open Data Licences", comment: "Settings: open data licences link"))
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                Divider()

                if let url = URL(string: "https://github.com/alexislours/metropolist") {
                    Link(destination: url) {
                        HStack {
                            Label {
                                Text(String(localized: "Source Code", comment: "Settings: GitHub source code link"))
                                    .font(.subheadline)
                            } icon: {
                                Image("GitHubIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Divider()

                Text(String(localized: "Made with ♡ for Paris transit riders", comment: "Settings: app tagline"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
