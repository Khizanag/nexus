import SwiftUI

struct CalendarSummaryCard: View {
    @State private var todayEvents: [CalendarEvent] = []
    @State private var isLoading = true
    @State private var showCalendarView = false

    private let calendarService = DefaultCalendarService.shared

    private var upcomingEvents: [CalendarEvent] {
        let now = Date()
        return todayEvents
            .filter { $0.endDate > now || $0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        Button {
            showCalendarView = true
        } label: {
            GlassCard {
                VStack(spacing: 0) {
                    headerView

                    if !todayEvents.isEmpty {
                        Divider().background(Color.nexusBorder)
                        contentView
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Calendar")
        .accessibilityValue(accessibilityValue)
        .sheet(isPresented: $showCalendarView) {
            CalendarView()
        }
        .task { await loadTodayEvents() }
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: DesignSystem.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(Color.nexusTeal.opacity(0.15))
                        .frame(width: DesignSystem.Size.Icon.badge, height: DesignSystem.Size.Icon.badge)
                    Image(systemName: "calendar")
                        .font(.nexusSubheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.nexusTeal)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar")
                        .font(.nexusHeadline)

                    if !calendarService.isAuthorized {
                        Text("Tap to enable")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    } else if isLoading {
                        Text("Loading…")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    } else if todayEvents.isEmpty {
                        Text("No events today")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("^[\(todayEvents.count) event](inflect: true) today")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .imageScale(.small)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            ForEach(upcomingEvents.prefix(3)) { event in
                CalendarEventMiniRow(event: event)

                if event.id != upcomingEvents.prefix(3).last?.id {
                    Divider()
                        .background(Color.nexusBorder)
                        .padding(.leading, 28)
                }
            }

            if upcomingEvents.count > 3 {
                HStack {
                    Spacer()
                    Text("+\(upcomingEvents.count - 3) more")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
        }
    }

    private var accessibilityValue: String {
        if !calendarService.isAuthorized { return "Tap to enable" }
        if isLoading { return "Loading" }
        if todayEvents.isEmpty { return "No events today" }
        return "^[\(todayEvents.count) event](inflect: true) today"
    }

    private func loadTodayEvents() async {
        guard calendarService.isAuthorized else {
            isLoading = false
            return
        }

        do {
            todayEvents = try await calendarService.fetchTodayEvents()
        } catch {
            print("Failed to load today's events: \(error)")
        }
        isLoading = false
    }
}

struct CalendarEventMiniRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 4, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(event.formattedTime)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}
