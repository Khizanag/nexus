import SwiftUI

struct CalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        .buttonStyle(.glass)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if calendarService.isAuthorized {
                        GlassEffectContainer(spacing: DesignSystem.Spacing.xs) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                            }
                            .buttonStyle(.glass)
                            .accessibilityLabel("Filter calendars")

                            Button {
                                eventEditorInitialDate = selectedDate
                                showEventEditor = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.glass)
                            .accessibilityLabel("New event")
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: showEventEditor) { _, newValue in
                if newValue, eventEditorInitialDate == Date() {
                    eventEditorInitialDate = selectedDate
                }
            }
            .sheet(item: $selectedEvent) { event in
                CalendarEventDetailView(event: event) {
                    Task { await loadEvents() }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSettings) {
                CalendarSettingsView(calendars: $calendars) {
                    Task { await loadEvents() }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .task { await initialize() }
            .refreshable { await loadEvents() }
        }
    }
}

// MARK: - Subviews

private extension CalendarView {
    var viewModePicker: some View {
        Picker("View mode", selection: $viewMode) {
            ForEach(CalendarViewMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .accessibilityLabel("Calendar view mode")
    }

    @ViewBuilder
    var calendarContent: some View {
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

    var authorizationView: some View {
        ContentUnavailableView {
            Label("Calendar Access Required", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("Allow Nexus to access your calendar to view and manage events.")
        } actions: {
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
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.nexusTeal)
        }
    }

    var loadingView: some View {
        ContentUnavailableView {
            Label("Loading Calendar", systemImage: "calendar")
        } description: {
            Text("Fetching your events…")
        }
    }
}

// MARK: - Computed Properties

private extension CalendarView {
    var eventsForSelectedDate: [CalendarEvent] {
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

    var upcomingEvents: [CalendarEvent] {
        let now = Date()
        return events
            .filter { $0.endDate >= now }
            .sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Actions

private extension CalendarView {
    func initialize() async {
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

    func loadEvents() async {
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
}
