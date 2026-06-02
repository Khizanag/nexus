import SwiftUI

struct CalendarAgendaView: View {
    let events: [CalendarEvent]
    let onEventTapped: (CalendarEvent) -> Void

    private let calendar = Calendar.current

    private var groupedEvents: [(Date, [CalendarEvent])] {
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.startDate)
        }

        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        if events.isEmpty {
            ContentUnavailableView(
                "No Upcoming Events",
                systemImage: "calendar.badge.checkmark",
                description: Text("Your schedule is clear")
            )
        } else {
            List {
                ForEach(groupedEvents, id: \.0) { date, dayEvents in
                    Section {
                        ForEach(dayEvents) { event in
                            Button {
                                onEventTapped(event)
                            } label: {
                                AgendaEventRow(event: event)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.nexusSurface)
                            .accessibilityLabel(event.title)
                            .accessibilityValue(event.formattedTime)
                        }
                    } header: {
                        AgendaSectionHeader(date: date)
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
            .listStyle(.plain)
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }
}

// MARK: - Section Header

private struct AgendaSectionHeader: View {
    let date: Date

    private let calendar = Calendar.current

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var isTomorrow: Bool {
        calendar.isDateInTomorrow(date)
    }

    private var dateTitle: String {
        if isToday {
            return "Today"
        } else if isTomorrow {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }

    private var relativeText: String? {
        if isToday || isTomorrow {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }

        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: date).day ?? 0
        if days > 0, days <= 7 {
            return "In \(days) days"
        }
        return nil
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateTitle)
                    .font(.nexusHeadline)
                    .foregroundStyle(isToday ? Color.nexusTeal : .primary)

                if let relative = relativeText {
                    Text(relative)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.nexusBackground)
    }
}

// MARK: - Event Row

private struct AgendaEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            timeColumn

            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(event.title)
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(event.calendarName)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .imageScale(.small)
                                .accessibilityHidden(true)
                            Text(location)
                                .lineLimit(1)
                        }
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .imageScale(.small)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.nexusSurface)
    }

    private var timeColumn: some View {
        VStack(spacing: 2) {
            if event.isAllDay {
                Text("All")
                    .font(.nexusCaption2)
                    .foregroundStyle(.secondary)
                Text("Day")
                    .font(.nexusCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.nexusTeal)
            } else {
                Text(formatTime(event.startDate))
                    .font(.nexusCaption)
                    .fontWeight(.medium)

                Text(formatTime(event.endDate))
                    .font(.nexusCaption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 48)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    CalendarAgendaView(
        events: [],
        onEventTapped: { _ in }
    )
}
