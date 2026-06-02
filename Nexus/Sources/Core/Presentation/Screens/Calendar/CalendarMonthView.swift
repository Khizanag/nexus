import SwiftUI

struct CalendarMonthView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let events: [CalendarEvent]
    let onDateSelected: (Date) -> Void
    let onEventTapped: (CalendarEvent) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .padding(.top, DesignSystem.Spacing.sm)

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
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.nexusTeal)
                    .frame(width: DesignSystem.Size.Button.tap, height: DesignSystem.Size.Button.tap)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Button {
                if reduceMotion {
                    currentMonth = Date()
                    selectedDate = Date()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        currentMonth = Date()
                        selectedDate = Date()
                    }
                }
            } label: {
                Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.nexusTitle3)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { nextMonth() } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.nexusTeal)
                    .frame(width: DesignSystem.Size.Button.tap, height: DesignSystem.Size.Button.tap)
            }
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
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
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }

    var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(daysInMonth, id: \.self) { date in
                Button {
                    if reduceMotion {
                        selectedDate = date
                    } else {
                        withAnimation(.spring(response: 0.2)) {
                            selectedDate = date
                        }
                    }
                    onDateSelected(date)
                } label: {
                    CalendarDayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                        events: eventsFor(date)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }

    var selectedDayEventsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.nexusHeadline)

                Spacer()

                Text("^[\(selectedDayEvents.count) event](inflect: true)")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.sm)

            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(selectedDayEvents) { event in
                        Button {
                            onEventTapped(event)
                        } label: {
                            CalendarEventRow(event: event)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(event.title)
                        .accessibilityValue(event.formattedTime)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
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
                    if reduceMotion { previousMonth() } else {
                        withAnimation(.spring(response: 0.3)) { previousMonth() }
                    }
                } else if value.translation.width < -threshold {
                    if reduceMotion { nextMonth() } else {
                        withAnimation(.spring(response: 0.3)) { nextMonth() }
                    }
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
