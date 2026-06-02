import SwiftUI

// MARK: - Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let events: [CalendarEvent]

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.nexusTeal)
                        .frame(width: 36, height: 36)
                } else if isToday {
                    Circle()
                        .strokeBorder(Color.nexusTeal, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }

                Text("\(calendar.component(.day, from: date))")
                    .font(.nexusSubheadline)
                    .fontWeight(isToday || isSelected ? .semibold : .regular)
                    .foregroundStyle(dayTextColor)
            }

            if !events.isEmpty {
                HStack(spacing: 3) {
                    ForEach(events.prefix(3).indices, id: \.self) { index in
                        Circle()
                            .fill(events[index].calendarColor)
                            .frame(width: 5, height: 5)
                            .accessibilityHidden(true)
                    }
                }
                .frame(height: 5)
            } else {
                Spacer().frame(height: 5)
            }
        }
        .frame(height: 52)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isToday ? [.isSelected] : [])
    }

    private var dayTextColor: Color {
        if isSelected { return .white }
        if !isCurrentMonth { return .nexusTextTertiary }
        return .primary
    }

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        var label = formatter.string(from: date)
        if isToday { label += ", today" }
        if isSelected { label += ", selected" }
        return label
    }

    private var accessibilityValue: String {
        if events.isEmpty { return "No events" }
        return "^[\(events.count) event](inflect: true)"
    }
}

// MARK: - Event Row

struct CalendarEventRow: View {
    let event: CalendarEvent
    let showDate: Bool

    init(event: CalendarEvent, showDate: Bool = false) {
        self.event = event
        self.showDate = showDate
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(event.title)
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    if showDate {
                        Text(event.startDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }

                    Text(event.formattedTime)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .imageScale(.small)
                                .accessibilityHidden(true)
                            Text(location)
                                .lineLimit(1)
                        }
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .imageScale(.small)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }
}

// MARK: - All-Day Event Chip

struct AllDayEventChip: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(event.calendarColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(event.title)
                .font(.nexusCaption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(event.calendarColor.opacity(0.15))
        }
    }
}

// MARK: - Time Indicator

struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat

    private var currentTimeOffset: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let minute = calendar.component(.minute, from: Date())
        return CGFloat(hour) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.nexusRed)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.nexusRed)
                .frame(height: 1)
        }
        .offset(y: currentTimeOffset)
        .accessibilityHidden(true)
    }
}

// MARK: - Hour Grid

struct HourGridLines: View {
    let hourHeight: CGFloat
    let showLabels: Bool

    init(hourHeight: CGFloat, showLabels: Bool = true) {
        self.hourHeight = hourHeight
        self.showLabels = showLabels
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                    if showLabels {
                        Text(formatHour(hour))
                            .font(.nexusCaption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 44, alignment: .trailing)
                    }

                    VStack {
                        Divider()
                            .background(Color.nexusBorder)
                        Spacer()
                    }
                }
                .frame(height: hourHeight)
                .id("hour-\(hour)")
            }
        }
        .accessibilityHidden(true)
    }

    private func formatHour(_ hour: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}

// MARK: - Day Event Block (for timeline views)

struct DayEventBlock: View {
    let event: CalendarEvent
    let hourHeight: CGFloat

    private var topOffset: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: event.startDate)
        let minute = calendar.component(.minute, from: event.startDate)
        return CGFloat(hour) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
    }

    private var height: CGFloat {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let hours = duration / 3600.0
        return max(CGFloat(hours) * hourHeight, 24)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.nexusCaption)
                .fontWeight(.medium)
                .lineLimit(height > 40 ? 2 : 1)

            if height > 40 {
                Text(event.formattedTime)
                    .font(.nexusCaption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(event.calendarColor)
        }
        .offset(y: topOffset)
        .accessibilityLabel(event.title)
        .accessibilityValue(event.formattedTime)
    }
}
