import SwiftUI

struct CalendarEventDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let event: CalendarEvent
    let onUpdate: () -> Void

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    private let calendarService = DefaultCalendarService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    detailsCard

                    if let notes = event.notes, !notes.isEmpty {
                        notesCard(notes)
                    }

                    dangerZone
                }
                .padding(20)
            }
            .background(Color.nexusBackground)
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        showEditSheet = true
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                CalendarEventEditorView(event: event, initialDate: event.startDate) { _ in
                    onUpdate()
                    dismiss()
                }
            }
            .confirmationDialog("Delete Event?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteEvent()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this event from your calendar.")
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(event.calendarColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "calendar")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(event.calendarColor)
            }

            VStack(spacing: 4) {
                Text(event.title)
                    .font(.nexusTitle2)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    Circle()
                        .fill(event.calendarColor)
                        .frame(width: 8, height: 8)

                    Text(event.calendarName)
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if event.isAllDay {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                    Text("All-day")
                }
                .font(.nexusCaption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    Capsule().fill(event.calendarColor)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
        }
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            DetailRow(
                icon: "calendar",
                title: "Date",
                value: formatDate()
            )

            Divider().background(Color.nexusBorder).padding(.leading, 44)

            DetailRow(
                icon: "clock",
                title: "Time",
                value: event.isAllDay ? "All-day" : event.formattedTimeRange
            )

            if let location = event.location, !location.isEmpty {
                Divider().background(Color.nexusBorder).padding(.leading, 44)

                DetailRow(
                    icon: "location.fill",
                    title: "Location",
                    value: location
                )
            }

            if let url = event.url {
                Divider().background(Color.nexusBorder).padding(.leading, 44)

                Link(destination: url) {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        Text("Open Link")
                            .font(.nexusSubheadline)
                            .foregroundStyle(Color.nexusTeal)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            if !event.alarms.isEmpty {
                Divider().background(Color.nexusBorder).padding(.leading, 44)

                DetailRow(
                    icon: "bell.fill",
                    title: "Alert",
                    value: event.alarms.first?.displayText ?? "None"
                )
            }
        }
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Text("Notes")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
            }

            Text(notes)
                .font(.nexusBody)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    private var dangerZone: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("Delete Event")
            }
            .font(.nexusSubheadline)
            .fontWeight(.medium)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
            }
        }
    }

    private func formatDate() -> String {
        if event.isMultiDay {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
        }
        return event.startDate.formatted(.dateTime.weekday(.wide).month().day().year())
    }

    private func deleteEvent() {
        Task {
            try? await calendarService.deleteEvent(event.id)
            onUpdate()
            dismiss()
        }
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.nexusSubheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
