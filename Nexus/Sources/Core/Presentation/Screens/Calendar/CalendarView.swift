import SwiftUI

struct CalendarView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var viewMode: CalendarViewMode = .day
    @State private var showEventEditor = false
    @State private var eventEditorInitialDate = Date()
    @State private var selectedEvent: CalendarEvent?
    @State private var events: [CalendarEvent] = []
    @State private var calendars: [CalendarSource] = []
    @State private var isLoading = true
    @State private var showSettings = false
    @State private var authorizationError = false

    private let calendarService = DefaultCalendarService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !calendarService.isAuthorized {
                    authorizationView
                } else if isLoading {
                    loadingView
                } else {
                    viewModePicker
                    calendarContent
                }
            }
            .background(Color.nexusBackground)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if calendarService.isAuthorized {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                            }

                            Button {
                                eventEditorInitialDate = selectedDate
                                showEventEditor = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showEventEditor) {
                CalendarEventEditorView(event: nil, initialDate: eventEditorInitialDate) { newEvent in
                    if let newEvent {
                        events.append(newEvent)
                    }
                }
            }
            .onChange(of: showEventEditor) { _, newValue in
                if newValue && eventEditorInitialDate == Date() {
                    eventEditorInitialDate = selectedDate
                }
            }
            .sheet(item: $selectedEvent) { event in
                CalendarEventDetailView(event: event) {
                    Task { await loadEvents() }
                }
            }
            .sheet(isPresented: $showSettings) {
                CalendarSettingsView(calendars: $calendars) {
                    Task { await loadEvents() }
                }
            }
            .task { await initialize() }
            .refreshable { await loadEvents() }
        }
    }

    private var viewModePicker: some View {
        HStack(spacing: 0) {
            ForEach(CalendarViewMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewMode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(.nexusSubheadline)
                        .fontWeight(viewMode == mode ? .semibold : .regular)
                        .foregroundStyle(viewMode == mode ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if viewMode == mode {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.nexusTeal)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch viewMode {
        case .day:
            CalendarDayView(
                selectedDate: $selectedDate,
                events: eventsForSelectedDate,
                onEventTapped: { event in
                    selectedEvent = event
                },
                onCreateEvent: { date in
                    eventEditorInitialDate = date
                    showEventEditor = true
                }
            )
        case .week:
            CalendarWeekView(
                selectedDate: $selectedDate,
                events: events,
                onEventTapped: { event in
                    selectedEvent = event
                }
            )
        case .month:
            CalendarMonthView(
                selectedDate: $selectedDate,
                currentMonth: $currentMonth,
                events: events,
                onDateSelected: { date in
                    selectedDate = date
                },
                onEventTapped: { event in
                    selectedEvent = event
                }
            )
        case .agenda:
            CalendarAgendaView(
                events: upcomingEvents,
                onEventTapped: { event in
                    selectedEvent = event
                }
            )
        }
    }

    private var authorizationView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(Color.nexusTeal)

            VStack(spacing: 8) {
                Text("Calendar Access Required")
                    .font(.nexusTitle3)

                Text("Allow Nexus to access your calendar to view and manage events.")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    do {
                        _ = try await calendarService.requestAuthorization()
                        await initialize()
                    } catch {
                        authorizationError = true
                    }
                }
            } label: {
                Text("Allow Access")
                    .font(.nexusSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.nexusTeal)
                    }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding(20)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading calendar...")
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
            Spacer()
        }
    }

    private var eventsForSelectedDate: [CalendarEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            if event.isAllDay {
                return calendar.isDate(event.startDate, inSameDayAs: selectedDate)
            }
            return calendar.isDate(event.startDate, inSameDayAs: selectedDate) ||
                   (event.startDate < selectedDate && event.endDate > selectedDate)
        }
        .sorted { $0.startDate < $1.startDate }
    }

    private var upcomingEvents: [CalendarEvent] {
        let now = Date()
        return events
            .filter { $0.endDate >= now }
            .sorted { $0.startDate < $1.startDate }
    }

    private func initialize() async {
        guard calendarService.isAuthorized else {
            isLoading = false
            return
        }

        do {
            calendars = try await calendarService.fetchCalendars()
            await loadEvents()
        } catch {
            isLoading = false
        }
    }

    private func loadEvents() async {
        isLoading = true
        do {
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
            let endOfMonth = calendar.date(byAdding: .month, value: 2, to: startOfMonth)!

            events = try await calendarService.fetchEvents(from: startOfMonth, to: endOfMonth)
        } catch {
            print("Failed to load events: \(error)")
        }
        isLoading = false
    }
}

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case agenda

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .agenda: "Agenda"
        }
    }
}

#Preview {
    CalendarView()
        .preferredColorScheme(.dark)
}
