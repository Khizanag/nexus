import SwiftUI
import SwiftData

struct HealthEntryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMetric: HealthMetricType = .weight
    @State private var value: String = ""
    @State private var date: Date = .now
    @State private var notes: String = ""

    @FocusState private var isValueFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(HealthMetricType.allCases, id: \.self) { metric in
                            Label(metric.displayName, systemImage: metric.icon)
                                .tag(metric)
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("0", text: $value)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .focused($isValueFocused)

                        Text(selectedMetric.defaultUnit)
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
            .navigationTitle("Log Health Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .disabled(value.isEmpty)
                }
            }
            .onAppear {
                isValueFocused = true
            }
        }
    }

    private func saveEntry() {
        guard let numericValue = Double(value) else { return }

        let entry = HealthEntryModel(
            type: selectedMetric,
            value: numericValue,
            unit: selectedMetric.defaultUnit,
            date: date,
            notes: notes
        )

        modelContext.insert(entry)
        dismiss()
    }
}

#Preview {
    HealthEntryEditorView()
        .preferredColorScheme(.dark)
}
