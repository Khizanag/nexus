import SwiftUI

struct CalendarDayView: View {
    @Binding var selectedDate: Date
    let events: [CalendarEvent]
    let onEventTapped: (CalendarEvent) -> Void
    var onCreateEvent: ((Date) -> Void)?

    @GestureState private var dragOffset: CGFloat = 0
    @State private var longPressLocation: CGPoint = .zero

    private let hourHeight: CGFloat = 60
    private let calendar = Calendar.current

    private var allDayEvents: [CalendarEvent] {
        events.filter { $0.isAllDay }
    }

    private var timedEvents: [CalendarEvent] {
        events.filter { !$0.isAllDay }
    }

    var body: some View {
        VStack(spacing: 0) {
            dayNavigationHeader

            if !allDayEvents.isEmpty {
                allDayEventsSection
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        HourGridLines(hourHeight: hourHeight)
                            .padding(.leading, 52)

                        if calendar.isDateInToday(selectedDate) {
                            CurrentTimeIndicator(hourHeight: hourHeight)
                                .padding(.leading, 52)
                        }

                        VStack(spacing: 0) {
                            ForEach(timedEvents) { event in
                                DayEventBlock(event: event, hourHeight: hourHeight)
                                    .padding(.leading, 60)
                                    .padding(.trailing, 16)
                                    .onTapGesture { onEventTapped(event) }
                            }
                        }
                    }
                    .frame(height: hourHeight * 24)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.5) {
                        let hour = Int(longPressLocation.y / hourHeight)
                        let minutes = Int((longPressLocation.y.truncatingRemainder(dividingBy: hourHeight) / hourHeight) * 60)
                        let roundedMinutes = (minutes / 15) * 15

                        if let eventDate = calendar.date(
                            bySettingHour: hour,
                            minute: roundedMinutes,
                            second: 0,
                            of: selectedDate
                        ) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onCreateEvent?(eventDate)
                        }
                    } onPressingChanged: { _ in }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                longPressLocation = value.location
                            }
                    )
                }
                .onAppear {
                    let hour = calendar.component(.hour, from: Date())
                    proxy.scrollTo("hour-\(max(0, hour - 1))", anchor: .top)
                }
            }
        }
        .gesture(daySwipeGesture)
    }
}

// MARK: - Subviews

private extension CalendarDayView {
    var dayNavigationHeader: some View {
        HStack {
            Button { previousDay() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.nexusTeal)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedDate = Date()
                }
            } label: {
                VStack(spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)

                    Text(selectedDate.formatted(.dateTime.month().day()))
                        .font(.nexusTitle3)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button { nextDay() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.nexusTeal)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    var allDayEventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All-day")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allDayEvents) { event in
                        AllDayEventChip(event: event)
                            .onTapGesture { onEventTapped(event) }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 8)
        .background(Color.nexusSurface)
    }

    var daySwipeGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.width > threshold {
                    withAnimation(.spring(response: 0.3)) { previousDay() }
                } else if value.translation.width < -threshold {
                    withAnimation(.spring(response: 0.3)) { nextDay() }
                }
            }
    }
}

// MARK: - Actions

private extension CalendarDayView {
    func previousDay() {
        selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    func nextDay() {
        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }
}
