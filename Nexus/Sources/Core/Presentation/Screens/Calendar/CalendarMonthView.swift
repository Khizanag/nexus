import SwiftUI

struct CalendarMonthView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let events: [CalendarEvent]
    let onDateSelected: (Date) -> Void
    let onEventTapped: (CalendarEvent) -> Void

    @GestureState private var dragOffset: CGFloat = 0

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayHeaders
            monthGrid

            if !selectedDayEvents.isEmpty {
                Divider()
                    .background(Color.nexusBorder)
                    .padding(.top, 12)

                selectedDayEventsSection
            }
        }
        .gesture(swipeGesture)
    }
}

// MARK: - Subviews

private extension CalendarMonthView {
    var monthHeader: some View {
        HStack {
            Button { previousMonth() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.nexusTeal)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    currentMonth = Date()
                    selectedDate = Date()
                }
            } label: {
                Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.nexusTitle3)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { nextMonth() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.nexusTeal)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
    }

    var weekdayHeaders: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol.prefix(2))
                    .font(.nexusCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(height: 32)
            }
        }
        .padding(.horizontal, 12)
    }

    var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(daysInMonth, id: \.self) { date in
                CalendarDayCell(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(date),
                    isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                    events: eventsFor(date)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.2)) {
                        selectedDate = date
                    }
                    onDateSelected(date)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    var selectedDayEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.nexusHeadline)

                Spacer()

                Text("^[\(selectedDayEvents.count) event](inflect: true)")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(selectedDayEvents) { event in
                        CalendarEventRow(event: event)
                            .onTapGesture { onEventTapped(event) }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    var swipeGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.width > threshold {
                    withAnimation(.spring(response: 0.3)) { previousMonth() }
                } else if value.translation.width < -threshold {
                    withAnimation(.spring(response: 0.3)) { nextMonth() }
                }
            }
    }
}

// MARK: - Computed Properties

private extension CalendarMonthView {
    var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            return []
        }

        var dates: [Date] = []
        var currentDate = monthFirstWeek.start

        while currentDate < monthLastWeek.end {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return dates
    }

    var selectedDayEvents: [CalendarEvent] {
        eventsFor(selectedDate)
    }

    func eventsFor(_ date: Date) -> [CalendarEvent] {
        events.filter { event in
            if event.isAllDay {
                return calendar.isDate(event.startDate, inSameDayAs: date)
            }
            return calendar.isDate(event.startDate, inSameDayAs: date) ||
                   (event.startDate < date && event.endDate > date)
        }
        .sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Actions

private extension CalendarMonthView {
    func previousMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    func nextMonth() {
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
}
