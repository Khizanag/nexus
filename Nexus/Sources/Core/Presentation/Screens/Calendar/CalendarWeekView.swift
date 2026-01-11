import SwiftUI

struct CalendarWeekView: View {
    @Binding var selectedDate: Date
    let events: [CalendarEvent]
    let onEventTapped: (CalendarEvent) -> Void

    @State private var weekOffset: Int = 0

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60

    private var weekDates: [Date] {
        let startOfWeek = calendar.date(
            byAdding: .weekOfYear,
            value: weekOffset,
            to: calendar.startOfWeek(for: Date())
        )!

        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }

    private var weekTitle: String {
        guard let first = weekDates.first, let last = weekDates.last else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: first)
        let endStr = formatter.string(from: last)

        if calendar.component(.month, from: first) == calendar.component(.month, from: last) {
            formatter.dateFormat = "d"
            return "\(startStr) - \(formatter.string(from: last))"
        }
        return "\(startStr) - \(endStr)"
    }

    var body: some View {
        VStack(spacing: 0) {
            weekHeader
            weekDayHeaders
            Divider().background(Color.nexusBorder)
            weekTimeGrid
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -50 {
                        withAnimation(.spring(response: 0.3)) {
                            weekOffset += 1
                        }
                    } else if value.translation.width > 50 {
                        withAnimation(.spring(response: 0.3)) {
                            weekOffset -= 1
                        }
                    }
                }
        )
    }

    private var weekHeader: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    weekOffset -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.nexusTeal)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(weekTitle)
                    .font(.nexusHeadline)

                if weekOffset == 0 {
                    Text("This Week")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    weekOffset += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.nexusTeal)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var weekDayHeaders: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 50)

            ForEach(weekDates, id: \.self) { date in
                VStack(spacing: 4) {
                    Text(dayOfWeek(date))
                        .font(.nexusCaption2)
                        .foregroundStyle(.secondary)

                    Text("\(calendar.component(.day, from: date))")
                        .font(.nexusSubheadline)
                        .fontWeight(calendar.isDateInToday(date) ? .bold : .regular)
                        .foregroundStyle(calendar.isDateInToday(date) ? .white : .primary)
                        .frame(width: 28, height: 28)
                        .background {
                            if calendar.isDateInToday(date) {
                                Circle().fill(Color.nexusTeal)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    selectedDate = date
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color.nexusSurface)
    }

    private var weekTimeGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    HourGridLines(hourHeight: hourHeight, showLabels: false)
                        .padding(.leading, 50)

                    HStack(spacing: 0) {
                        timeLabels
                        daysColumns
                    }

                    currentTimeIndicatorForWeek
                }
                .id("weekGrid")
            }
            .onAppear {
                let currentHour = calendar.component(.hour, from: Date())
                if currentHour >= 8 {
                    proxy.scrollTo("weekGrid", anchor: UnitPoint(x: 0, y: Double(currentHour - 2) / 24.0))
                }
            }
        }
    }

    private var timeLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<24) { hour in
                Text(formatHour(hour))
                    .font(.nexusCaption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 8)
                    .offset(y: -6)
            }
        }
    }

    private var daysColumns: some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: hourHeight * 24)

                    ForEach(eventsFor(date)) { event in
                        if !event.isAllDay {
                            weekEventBlock(event: event, date: date)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.nexusBorder)
                        .frame(width: 0.5)
                }
            }
        }
    }

    private func weekEventBlock(event: CalendarEvent, date: Date) -> some View {
        let startOfDay = calendar.startOfDay(for: date)
        let startMinutes = calendar.dateComponents([.hour, .minute], from: event.startDate)
        let endMinutes = calendar.dateComponents([.hour, .minute], from: event.endDate)

        let startOffset = (CGFloat(startMinutes.hour ?? 0) + CGFloat(startMinutes.minute ?? 0) / 60) * hourHeight
        let endOffset = (CGFloat(endMinutes.hour ?? 0) + CGFloat(endMinutes.minute ?? 0) / 60) * hourHeight
        let height = max(endOffset - startOffset, 20)

        return Button {
            onEventTapped(event)
        } label: {
            Text(event.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
                .frame(height: height, alignment: .top)
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(event.calendarColor)
                }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 2)
        .offset(y: startOffset)
    }

    @ViewBuilder
    private var currentTimeIndicatorForWeek: some View {
        if weekOffset == 0 {
            let now = Date()
            let todayIndex = weekDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: now) })

            if let index = todayIndex {
                let components = calendar.dateComponents([.hour, .minute], from: now)
                let offset = (CGFloat(components.hour ?? 0) + CGFloat(components.minute ?? 0) / 60) * hourHeight

                GeometryReader { geometry in
                    let dayWidth = (geometry.size.width - 50) / 7
                    let xOffset = 50 + dayWidth * CGFloat(index)

                    HStack(spacing: 0) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)

                        Rectangle()
                            .fill(Color.red)
                            .frame(width: dayWidth - 4, height: 2)
                    }
                    .offset(x: xOffset - 4, y: offset - 4)
                }
            }
        }
    }

    private func eventsFor(_ date: Date) -> [CalendarEvent] {
        events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date) ||
            (event.startDate < date && event.endDate > date)
        }
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date).lowercased()
    }
}

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    CalendarWeekView(
        selectedDate: .constant(Date()),
        events: [],
        onEventTapped: { _ in }
    )
    .preferredColorScheme(.dark)
}
