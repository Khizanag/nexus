import SwiftUI

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    var title: String
    var notes: String?
    var location: String?
    var url: URL?
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendarId: String
    var calendarColor: Color
    var calendarName: String
    var alarms: [EventAlarm]

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    var isMultiDay: Bool {
        !Calendar.current.isDate(startDate, inSameDayAs: endDate)
    }

    var formattedTime: String {
        if isAllDay { return "All-day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    var formattedTimeRange: String {
        if isAllDay { return "All-day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

struct EventAlarm: Hashable {
    let relativeOffset: TimeInterval

    var displayText: String {
        let minutes = abs(Int(relativeOffset / 60))
        if minutes == 0 { return "At time of event" }
        if minutes < 60 { return "\(minutes) min before" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hour\(hours > 1 ? "s" : "") before" }
        let days = hours / 24
        return "\(days) day\(days > 1 ? "s" : "") before"
    }

    static let none = EventAlarm(relativeOffset: Double.infinity)
    static let atTime = EventAlarm(relativeOffset: 0)
    static let fiveMinutes = EventAlarm(relativeOffset: -5 * 60)
    static let fifteenMinutes = EventAlarm(relativeOffset: -15 * 60)
    static let thirtyMinutes = EventAlarm(relativeOffset: -30 * 60)
    static let oneHour = EventAlarm(relativeOffset: -60 * 60)
    static let twoHours = EventAlarm(relativeOffset: -2 * 60 * 60)
    static let oneDay = EventAlarm(relativeOffset: -24 * 60 * 60)

    static var allOptions: [EventAlarm] {
        [.atTime, .fiveMinutes, .fifteenMinutes, .thirtyMinutes, .oneHour, .twoHours, .oneDay]
    }
}
