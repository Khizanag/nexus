import SwiftUI

struct CalendarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var calendars: [CalendarSource]
    let onUpdate: () -> Void

    private let calendarService = DefaultCalendarService.shared

    private var groupedCalendars: [(String, [Binding<CalendarSource>])] {
        let bindingArray = $calendars

        var groups: [String: [Binding<CalendarSource>]] = [:]

        for i in calendars.indices {
            let sourceName = calendars[i].sourceName
            if groups[sourceName] == nil {
                groups[sourceName] = []
            }
            groups[sourceName]?.append(bindingArray[i])
        }

        return groups.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedCalendars, id: \.0) { sourceName, sourceCalendars in
                    Section {
                        ForEach(sourceCalendars) { $calendar in
                            CalendarSettingsRow(
                                calendar: $calendar,
                                onVisibilityChanged: { isVisible in
                                    calendarService.setCalendarVisibility(calendar.id, isVisible: isVisible)
                                }
                            )
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Image(systemName: iconForSource(sourceCalendars.first?.wrappedValue.sourceType ?? .local))
                                .font(.system(size: 12))
                                .foregroundStyle(Color.nexusTeal)

                            Text(sourceName)
                        }
                    }
                }
            }
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onUpdate()
                        dismiss()
                    }
                }
            }
        }
    }

    private func iconForSource(_ type: CalendarSourceType) -> String {
        switch type {
        case .local: "iphone"
        case .calDAV: "icloud"
        case .exchange: "building.2.fill"
        case .subscription: "globe"
        case .birthday: "gift.fill"
        }
    }
}

// MARK: - Calendar Row

private struct CalendarSettingsRow: View {
    @Binding var calendar: CalendarSource
    let onVisibilityChanged: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(calendar.color)
                .frame(width: 16, height: 16)

            Text(calendar.title)
                .font(.nexusSubheadline)

            Spacer()

            Toggle("", isOn: $calendar.isVisible)
                .labelsHidden()
                .onChange(of: calendar.isVisible) { _, newValue in
                    onVisibilityChanged(newValue)
                }
        }
    }
}
