import SwiftUI

struct TimelineDateNavigator: View {
    let selectedDate: Date
    let canGoBack: Bool
    let canGoForward: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onCalendarTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .disabled(!canGoBack)
            .accessibilityLabel(
                String(localized: "Previous day with travels", comment: "Timeline: previous day button")
            )

            Spacer()

            Text(selectedDate, format: .dateTime.weekday(.abbreviated).month(.wide).day())
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button {
                onNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
            }
            .disabled(!canGoForward)
            .accessibilityLabel(
                String(localized: "Next day with travels", comment: "Timeline: next day button")
            )

            Button {
                onCalendarTap()
            } label: {
                Image(systemName: "calendar")
                    .font(.body)
            }
            .accessibilityLabel(
                String(localized: "Jump to date", comment: "Timeline: calendar button accessibility label")
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
    }
}
