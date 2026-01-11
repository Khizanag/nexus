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
        VStack(spacing: 4) {
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
                    }
                }
                .frame(height: 5)
            } else {
                Spacer().frame(height: 5)
            }
        }
        .frame(height: 52)
    }

    private var dayTextColor: Color {
        if isSelected { return .white }
        if !isCurrentMonth { return .nexusTextTertiary }
        return .primary
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
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
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
                                .font(.system(size: 8))
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
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

            Text(event.title)
                .font(.nexusCaption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
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
                HStack(alignment: .top, spacing: 8) {
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
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(event.calendarColor)
        }
        .offset(y: topOffset)
    }
}

// MARK: - Empty State

struct CalendarEmptyState: View {
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.nexusTeal)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
