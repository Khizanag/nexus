import SwiftUI
import SwiftData

struct QuickHealthEntryView: View {
    let metric: HealthMetricType

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var value: String = ""
    @State private var date: Date = .now
    @State private var notes: String = ""
    @FocusState private var isValueFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: metric.icon)
                            .font(.nexusTitle2)
                            .foregroundStyle(metricColor)
                            .frame(width: 40)
                            .accessibilityHidden(true)

                        TextField("0", text: $value)
                            .font(.nexusDisplayNumber(.title))
                            .keyboardType(.decimalPad)
                            .focused($isValueFocused)
                            .accessibilityLabel("\(metric.displayName) value")

                        Text(metric.defaultUnit)
                            .font(.nexusTitle2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Date & Time") {
                    DatePicker("Date & Time", selection: $date)
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityLabel("Notes")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .navigationTitle("Log \(metric.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveEntry() }
                        .fontWeight(.semibold)
                        .disabled(value.isEmpty)
                }
            }
            .onAppear { isValueFocused = true }
        }
    }
}

private extension QuickHealthEntryView {
    var metricColor: Color {
        HealthMetricColorMapper.color(for: metric.color)
    }

    func saveEntry() {
        guard let numericValue = Double(value) else { return }
        let entry = HealthEntryModel(
            type: metric,
            value: numericValue,
            unit: metric.defaultUnit,
            date: date,
            notes: notes
        )
        modelContext.insert(entry)
        dismiss()
    }
}
