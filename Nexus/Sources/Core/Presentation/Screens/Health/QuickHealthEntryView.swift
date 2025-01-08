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
                            .font(.system(size: 24))
                            .foregroundStyle(metricColor)
                            .frame(width: 40)

                        TextField("0", text: $value)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .focused($isValueFocused)

                        Text(metric.defaultUnit)
                            .font(.nexusTitle2)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    DatePicker("Date & Time", selection: $date)
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
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
