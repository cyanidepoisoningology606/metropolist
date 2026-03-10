import SwiftUI
import UIKit

struct TimelineCalendarPicker: UIViewRepresentable {
    let daysWithTravels: Set<Date>
    let selectedDate: Date
    let onDateSelected: (Date) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(daysWithTravels: daysWithTravels, onDateSelected: onDateSelected)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar.current
        calendarView.availableDateRange = DateInterval(
            start: daysWithTravels.min() ?? Date(),
            end: Date()
        )
        calendarView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        calendarView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.selectedDate = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        calendarView.selectionBehavior = selection

        return calendarView
    }

    func updateUIView(_: UICalendarView, context: Context) {
        context.coordinator.daysWithTravels = daysWithTravels
        context.coordinator.onDateSelected = onDateSelected
    }

    final class Coordinator: NSObject, UICalendarSelectionSingleDateDelegate {
        var daysWithTravels: Set<Date>
        var onDateSelected: (Date) -> Void

        init(daysWithTravels: Set<Date>, onDateSelected: @escaping (Date) -> Void) {
            self.daysWithTravels = daysWithTravels
            self.onDateSelected = onDateSelected
        }

        func dateSelection(_: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
            guard let dateComponents, let date = Calendar.current.date(from: dateComponents) else { return false }
            let day = Calendar.current.startOfDay(for: date)
            return daysWithTravels.contains(day)
        }

        func dateSelection(_: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents, let date = Calendar.current.date(from: dateComponents) else { return }
            let day = Calendar.current.startOfDay(for: date)
            onDateSelected(day)
        }
    }
}
