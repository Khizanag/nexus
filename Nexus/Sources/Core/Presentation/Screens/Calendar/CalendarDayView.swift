import SwiftUI

struct CalendarDayView: View {
    @Binding var selectedDate: Date
    let events: [CalendarEvent]
    let onEventTapped: (CalendarEvent) -> Void
    var onCreateEvent: ((Date) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var dragOffset: CGFloat = 0
    @State private var longPressLocation: CGPoint = .zero
    @State private var hapticTrigger = false

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
                                Button {
                                    onEventTapped(event)
                                } label: {
                                    DayEventBlock(event: event, hourHeight: hourHeight)
                                        .padding(.leading, 60)
                                        .padding(.trailing, DesignSystem.Spacing.md)
                                }
                                .buttonStyle(.plain)
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
                            hapticTrigger.toggle()
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
                .scrollEdgeEffectStyle(.soft, for: .top)
                .onAppear {
                    let hour = calendar.component(.hour, from: Date())
                    proxy.scrollTo("hour-\(max(0, hour - 1))", anchor: .top)
                }
            }
        }
        .gesture(daySwipeGesture)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
    }
}

// MARK: - Subviews

private extension CalendarDayView {
    var dayNavigationHeader: some View {
        HStack {
            Button { previousDay() } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.nexusTeal)
                    .frame(width: DesignSystem.Size.Button.tap, height: DesignSystem.Size.Button.tap)
            }
            .accessibilityLabel("Previous day")

            Spacer()

            Button {
                if reduceMotion {
                    selectedDate = Date()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        selectedDate = Date()
                    }
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
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.nexusTeal)
                    .frame(width: DesignSystem.Size.Button.tap, height: DesignSystem.Size.Button.tap)
            }
            .accessibilityLabel("Next day")
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    var allDayEventsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("All-day")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignSystem.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(allDayEvents) { event in
                        Button {
                            onEventTapped(event)
                        } label: {
                            AllDayEventChip(event: event)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(event.title)
                        .accessibilityValue("All day")
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
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
                    if reduceMotion { previousDay() } else {
                        withAnimation(.spring(response: 0.3)) { previousDay() }
                    }
                } else if value.translation.width < -threshold {
                    if reduceMotion { nextDay() } else {
                        withAnimation(.spring(response: 0.3)) { nextDay() }
                    }
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
