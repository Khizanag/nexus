import SwiftUI

struct CalendarEventEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let event: CalendarEvent?
    let initialDate: Date
    let onSave: (CalendarEvent?) -> Void

    @State private var title = ""
    @State private var notes = ""
    @State private var location = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = false
    @State private var selectedCalendarId: String?
    @State private var selectedAlarm: EventAlarm = .none
    @State private var calendars: [CalendarSource] = []
    @State private var isSaving = false

    @FocusState private var isTitleFocused: Bool

    private let calendarService = DefaultCalendarService.shared

    init(event: CalendarEvent?, initialDate: Date = Date(), onSave: @escaping (CalendarEvent?) -> Void) {
        self.event = event
        self.initialDate = initialDate
        self.onSave = onSave

        if let event {
            _title = State(initialValue: event.title)
            _notes = State(initialValue: event.notes ?? "")
            _location = State(initialValue: event.location ?? "")
            _startDate = State(initialValue: event.startDate)
            _endDate = State(initialValue: event.endDate)
            _isAllDay = State(initialValue: event.isAllDay)
            _selectedCalendarId = State(initialValue: event.calendarId)
            _selectedAlarm = State(initialValue: event.alarms.first ?? .none)
        } else {
            let calendar = Calendar.current
            let roundedStart = calendar.nextDate(
                after: initialDate,
                matching: DateComponents(minute: 0),
                matchingPolicy: .nextTime
            ) ?? initialDate
            _startDate = State(initialValue: roundedStart)
            _endDate = State(initialValue: roundedStart.addingTimeInterval(3600))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Event title", text: $title)
                        .font(.nexusHeadline)
                        .focused($isTitleFocused)

                    TextField("Location", text: $location)
                        .font(.nexusBody)
                }

                Section {
                    Toggle("All-day", isOn: $isAllDay.animation())

                    DatePicker(
                        "Starts",
                        selection: $startDate,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    .onChange(of: startDate) { _, newValue in
                        if endDate <= newValue {
                            endDate = newValue.addingTimeInterval(3600)
                        }
                    }

                    DatePicker(
                        "Ends",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                }

                Section {
                    Picker("Calendar", selection: $selectedCalendarId) {
                        ForEach(editableCalendars) { calendar in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(calendar.color)
                                    .frame(width: 10, height: 10)
                                Text(calendar.title)
                            }
                            .tag(calendar.id as String?)
                        }
                    }
                }

                Section {
                    Picker("Alert", selection: $selectedAlarm) {
                        Text("None").tag(EventAlarm.none)
                        ForEach(EventAlarm.allOptions, id: \.relativeOffset) { alarm in
                            Text(alarm.displayText).tag(alarm)
                        }
                    }
                }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if event != nil {
                    Section {
                        Button(role: .destructive) {
                            deleteEvent()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Event")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .navigationTitle(event == nil ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveEvent()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || isSaving || selectedCalendarId == nil)
                }
            }
            .onAppear {
                if event == nil { isTitleFocused = true }
            }
            .task { await loadCalendars() }
        }
    }

    private var editableCalendars: [CalendarSource] {
        calendars.filter(\.isEditable)
    }

    private func loadCalendars() async {
        do {
            calendars = try await calendarService.fetchCalendars()
            if selectedCalendarId == nil {
                selectedCalendarId = editableCalendars.first?.id
            }
        } catch {
            print("Failed to load calendars: \(error)")
        }
    }

    private func saveEvent() {
        guard let calendarId = selectedCalendarId else { return }

        isSaving = true

        let alarms = selectedAlarm.relativeOffset == Double.infinity ? [] : [selectedAlarm]

        let eventToSave = CalendarEvent(
            id: event?.id ?? UUID().uuidString,
            title: title,
            notes: notes.isEmpty ? nil : notes,
            location: location.isEmpty ? nil : location,
            url: nil,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            calendarId: calendarId,
            calendarColor: calendars.first(where: { $0.id == calendarId })?.color ?? .nexusTeal,
            calendarName: calendars.first(where: { $0.id == calendarId })?.title ?? "",
            alarms: alarms
        )

        Task {
            do {
                if event != nil {
                    try await calendarService.updateEvent(eventToSave)
                    onSave(eventToSave)
                } else {
                    let newEvent = try await calendarService.createEvent(eventToSave, in: calendarId)
                    onSave(newEvent)
                }
                dismiss()
            } catch {
                print("Failed to save event: \(error)")
                isSaving = false
            }
        }
    }

    private func deleteEvent() {
        guard let eventId = event?.id else { return }

        Task {
            try? await calendarService.deleteEvent(eventId)
            onSave(nil)
            dismiss()
        }
    }
}

#Preview {
    CalendarEventEditorView(event: nil) { _ in }
        .preferredColorScheme(.dark)
}
