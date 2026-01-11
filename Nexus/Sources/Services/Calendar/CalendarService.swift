import EventKit
import SwiftUI

@MainActor
protocol CalendarService: Sendable {
    var authorizationStatus: EKAuthorizationStatus { get }
    var isAuthorized: Bool { get }

    func requestAuthorization() async throws -> Bool
    func fetchCalendars() async throws -> [CalendarSource]
    func setCalendarVisibility(_ calendarId: String, isVisible: Bool)
    func getVisibleCalendarIds() -> Set<String>
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent]
    func fetchTodayEvents() async throws -> [CalendarEvent]
    func fetchUpcomingEvents(days: Int) async throws -> [CalendarEvent]
    func createEvent(_ event: CalendarEvent, in calendarId: String) async throws -> CalendarEvent
    func updateEvent(_ event: CalendarEvent) async throws
    func deleteEvent(_ eventId: String) async throws
}

@MainActor
final class DefaultCalendarService: CalendarService {
    static let shared = DefaultCalendarService()

    private let eventStore = EKEventStore()
    private let visibilityKey = "calendarVisibility"

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }

    func requestAuthorization() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await eventStore.requestAccess(to: .event)
        }
    }

    func fetchCalendars() async throws -> [CalendarSource] {
        guard isAuthorized else { throw CalendarError.notAuthorized }

        let visibleIds = getVisibleCalendarIds()
        return eventStore.calendars(for: .event).map { calendar in
            CalendarSource(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                color: Color(cgColor: calendar.cgColor),
                sourceType: mapSourceType(calendar.source.sourceType),
                sourceName: calendar.source.title,
                isEditable: calendar.allowsContentModifications,
                isVisible: visibleIds.isEmpty || visibleIds.contains(calendar.calendarIdentifier)
            )
        }
    }

    func setCalendarVisibility(_ calendarId: String, isVisible: Bool) {
        var visibleIds = getVisibleCalendarIds()
        if isVisible {
            visibleIds.insert(calendarId)
        } else {
            visibleIds.remove(calendarId)
        }
        UserDefaults.standard.set(Array(visibleIds), forKey: visibilityKey)
    }

    func getVisibleCalendarIds() -> Set<String> {
        let ids = UserDefaults.standard.stringArray(forKey: visibilityKey) ?? []
        return Set(ids)
    }

    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        guard isAuthorized else { throw CalendarError.notAuthorized }

        let visibleIds = getVisibleCalendarIds()
        let calendars = eventStore.calendars(for: .event).filter {
            visibleIds.isEmpty || visibleIds.contains($0.calendarIdentifier)
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars.isEmpty ? nil : calendars
        )

        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map(mapEvent)
    }

    func fetchTodayEvents() async throws -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return try await fetchEvents(from: startOfDay, to: endOfDay)
    }

    func fetchUpcomingEvents(days: Int) async throws -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: days, to: startOfDay)!
        return try await fetchEvents(from: startOfDay, to: endDate)
    }

    func createEvent(_ event: CalendarEvent, in calendarId: String) async throws -> CalendarEvent {
        guard isAuthorized else { throw CalendarError.notAuthorized }

        guard let calendar = eventStore.calendar(withIdentifier: calendarId) else {
            throw CalendarError.calendarNotFound
        }

        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.calendar = calendar
        ekEvent.title = event.title
        ekEvent.notes = event.notes
        ekEvent.location = event.location
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.isAllDay = event.isAllDay
        ekEvent.url = event.url

        for alarm in event.alarms {
            if alarm.relativeOffset != Double.infinity {
                ekEvent.addAlarm(EKAlarm(relativeOffset: alarm.relativeOffset))
            }
        }

        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            return mapEvent(ekEvent)
        } catch {
            throw CalendarError.createFailed
        }
    }

    func updateEvent(_ event: CalendarEvent) async throws {
        guard isAuthorized else { throw CalendarError.notAuthorized }

        guard let ekEvent = eventStore.event(withIdentifier: event.id) else {
            throw CalendarError.eventNotFound
        }

        ekEvent.title = event.title
        ekEvent.notes = event.notes
        ekEvent.location = event.location
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.isAllDay = event.isAllDay
        ekEvent.url = event.url

        ekEvent.alarms?.forEach { ekEvent.removeAlarm($0) }
        for alarm in event.alarms {
            if alarm.relativeOffset != Double.infinity {
                ekEvent.addAlarm(EKAlarm(relativeOffset: alarm.relativeOffset))
            }
        }

        do {
            try eventStore.save(ekEvent, span: .thisEvent)
        } catch {
            throw CalendarError.updateFailed
        }
    }

    func deleteEvent(_ eventId: String) async throws {
        guard isAuthorized else { throw CalendarError.notAuthorized }

        guard let ekEvent = eventStore.event(withIdentifier: eventId) else {
            throw CalendarError.eventNotFound
        }

        do {
            try eventStore.remove(ekEvent, span: .thisEvent)
        } catch {
            throw CalendarError.deleteFailed
        }
    }
}

// MARK: - Private Helpers

private extension DefaultCalendarService {
    func mapSourceType(_ type: EKSourceType) -> CalendarSourceType {
        switch type {
        case .local: .local
        case .calDAV: .calDAV
        case .exchange: .exchange
        case .subscribed: .subscription
        case .birthdays: .birthday
        @unknown default: .local
        }
    }

    func mapEvent(_ ekEvent: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: ekEvent.eventIdentifier,
            title: ekEvent.title ?? "Untitled",
            notes: ekEvent.notes,
            location: ekEvent.location,
            url: ekEvent.url,
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            isAllDay: ekEvent.isAllDay,
            calendarId: ekEvent.calendar.calendarIdentifier,
            calendarColor: Color(cgColor: ekEvent.calendar.cgColor),
            calendarName: ekEvent.calendar.title,
            alarms: ekEvent.alarms?.map { EventAlarm(relativeOffset: $0.relativeOffset) } ?? []
        )
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case notAuthorized
    case calendarNotFound
    case eventNotFound
    case createFailed
    case updateFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Calendar access not authorized"
        case .calendarNotFound: "Calendar not found"
        case .eventNotFound: "Event not found"
        case .createFailed: "Failed to create event"
        case .updateFailed: "Failed to update event"
        case .deleteFailed: "Failed to delete event"
        }
    }
}
