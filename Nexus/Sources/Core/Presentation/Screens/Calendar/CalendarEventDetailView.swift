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
            List {
                headerSection
                detailsSection

                if let notes = event.notes, !notes.isEmpty {
                    notesSection(notes)
                }

                deleteSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.glass)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        showEditSheet = true
                    }
                    .buttonStyle(.glass)
                }
            }
            .sheet(isPresented: $showEditSheet) {
                CalendarEventEditorView(event: event, initialDate: event.startDate) { _ in
                    onUpdate()
                    dismiss()
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
}

// MARK: - Sections

private extension CalendarEventDetailView {
    var headerSection: some View {
        Section {
            GlassCard(tint: event.calendarColor) {
                VStack(spacing: DesignSystem.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(event.calendarColor.opacity(0.15))
                            .frame(width: DesignSystem.Size.Icon.badge * 2, height: DesignSystem.Size.Icon.badge * 2)

                        Image(systemName: "calendar")
                            .font(.nexusTitle2)
                            .fontWeight(.semibold)
                            .foregroundStyle(event.calendarColor)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text(event.title)
                            .font(.nexusTitle2)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(event.calendarColor)
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)

                            Text(event.calendarName)
                                .font(.nexusSubheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if event.isAllDay {
                        HStack(spacing: 6) {
                            Image(systemName: "sun.max.fill")
                                .accessibilityHidden(true)
                            Text("All-day")
                        }
                        .font(.nexusCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, 6)
                        .background {
                            Capsule().fill(event.calendarColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    var detailsSection: some View {
        Section {
            LabeledContent {
                Text(formatDate())
                    .font(.nexusSubheadline)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Date", systemImage: "calendar")
                    .font(.nexusSubheadline)
            }

            LabeledContent {
                Text(event.isAllDay ? "All-day" : event.formattedTimeRange)
                    .font(.nexusSubheadline)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Time", systemImage: "clock")
                    .font(.nexusSubheadline)
            }

            if let location = event.location, !location.isEmpty {
                LabeledContent {
                    Text(location)
                        .font(.nexusSubheadline)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Location", systemImage: "location.fill")
                        .font(.nexusSubheadline)
                }
            }

            if let url = event.url {
                Link(destination: url) {
                    Label("Open Link", systemImage: "link")
                        .font(.nexusSubheadline)
                        .foregroundStyle(Color.nexusTeal)
                }
            }

            if !event.alarms.isEmpty {
                LabeledContent {
                    Text(event.alarms.first?.displayText ?? "None")
                        .font(.nexusSubheadline)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Alert", systemImage: "bell.fill")
                        .font(.nexusSubheadline)
                }
            }
        }
    }

    func notesSection(_ notes: String) -> some View {
        Section("Notes") {
            Text(notes)
                .font(.nexusBody)
        }
    }

    var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Event", systemImage: "trash.fill")
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    func formatDate() -> String {
        if event.isMultiDay {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
        }
        return event.startDate.formatted(.dateTime.weekday(.wide).month().day().year())
    }

    func deleteEvent() {
        Task {
            try? await calendarService.deleteEvent(event.id)
            onUpdate()
            dismiss()
        }
    }
}
