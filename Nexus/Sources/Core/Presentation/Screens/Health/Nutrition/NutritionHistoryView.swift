import SwiftUI
import SwiftData
import Charts

struct NutritionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NutritionEntryModel.date, order: .reverse) private var entries: [NutritionEntryModel]

    @AppStorage("dailyCalorieGoal") private var calorieGoal = 2000

    @State private var selectedTimeRange: TimeRange = .week

    private var chartData: [DailyNutritionData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let daysToShow: Int
        switch selectedTimeRange {
        case .week: daysToShow = 7
        case .month: daysToShow = 30
        }

        var data: [DailyNutritionData] = []

        for dayOffset in (0..<daysToShow).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: date) }

            let totalCalories = dayEntries.reduce(0) { $0 + $1.calories }
            let totalCarbs = dayEntries.reduce(0) { $0 + $1.carbs }
            let totalProtein = dayEntries.reduce(0) { $0 + $1.protein }
            let totalFats = dayEntries.reduce(0) { $0 + $1.fats }

            data.append(DailyNutritionData(
                date: date,
                calories: totalCalories,
                carbs: totalCarbs,
                protein: totalProtein,
                fats: totalFats
            ))
        }

        return data
    }

    private var averageCalories: Double {
        let nonZeroDays = chartData.filter { $0.calories > 0 }
        guard !nonZeroDays.isEmpty else { return 0 }
        return nonZeroDays.reduce(0) { $0 + $1.calories } / Double(nonZeroDays.count)
    }

    private var totalEntries: Int { entries.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    timeRangePicker
                    calorieChart
                    statsSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.nexusBackground)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Time Range

private enum TimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
}

// MARK: - Chart Data

private struct DailyNutritionData: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let carbs: Double
    let protein: Double
    let fats: Double
}

// MARK: - Subviews

private extension NutritionHistoryView {
    var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    var calorieChart: some View {
        NexusCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calories")
                            .font(.nexusHeadline)
                            .foregroundStyle(Color.nexusTextPrimary)

                        Text("Daily intake over \(selectedTimeRange.rawValue.lowercased())")
                            .font(.nexusCaption)
                            .foregroundStyle(Color.nexusTextSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(averageCalories))")
                            .font(.nexusTitle2)
                            .foregroundStyle(Color.nexusOrange)

                        Text("avg kcal/day")
                            .font(.nexusCaption)
                            .foregroundStyle(Color.nexusTextTertiary)
                    }
                }

                Chart {
                    RuleMark(y: .value("Goal", Double(calorieGoal)))
                        .foregroundStyle(Color.nexusGreen.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                    ForEach(chartData) { data in
                        BarMark(
                            x: .value("Date", data.date, unit: .day),
                            y: .value("Calories", data.calories)
                        )
                        .foregroundStyle(barColor(for: data.calories))
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: selectedTimeRange == .week ? .day : .weekOfYear)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: selectedTimeRange == .week ? .dateTime.weekday(.abbreviated) : .dateTime.day())
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
    }

    var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.nexusHeadline)
                .foregroundStyle(Color.nexusTextPrimary)

            HStack(spacing: 12) {
                StatCard(
                    title: "Total Entries",
                    value: "\(totalEntries)",
                    icon: "list.bullet",
                    color: .nexusBlue
                )

                StatCard(
                    title: "Avg Calories",
                    value: "\(Int(averageCalories))",
                    icon: "flame.fill",
                    color: .nexusOrange
                )
            }
        }
    }

    var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Days")
                .font(.nexusHeadline)
                .foregroundStyle(Color.nexusTextPrimary)

            VStack(spacing: 8) {
                ForEach(chartData.prefix(7).reversed(), id: \.id) { data in
                    HistoryDayRow(data: data, goal: calorieGoal)
                }
            }
        }
    }

    func barColor(for calories: Double) -> Color {
        let progress = calories / Double(calorieGoal)
        if progress >= 1.0 { return .nexusRed }
        if progress >= 0.9 { return .nexusOrange }
        return .nexusOrange.opacity(0.8)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        NexusCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.nexusCaption)
                        .foregroundStyle(color)

                    Text(title)
                        .font(.nexusCaption)
                        .foregroundStyle(Color.nexusTextSecondary)
                }

                Text(value)
                    .font(.nexusTitle2)
                    .foregroundStyle(Color.nexusTextPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - History Day Row

private struct HistoryDayRow: View {
    let data: DailyNutritionData
    let goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return data.calories / Double(goal)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(data.date, format: .dateTime.weekday(.abbreviated).month().day())
                    .font(.nexusSubheadline)
                    .foregroundStyle(Color.nexusTextPrimary)

                if data.calories > 0 {
                    HStack(spacing: 6) {
                        Text("C: \(Int(data.carbs))g")
                            .foregroundStyle(Color.nexusBlue)
                        Text("P: \(Int(data.protein))g")
                            .foregroundStyle(Color.nexusRed)
                        Text("F: \(Int(data.fats))g")
                            .foregroundStyle(Color.nexusPurple)
                    }
                    .font(.system(size: 10))
                }
            }

            Spacer()

            if data.calories > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(data.calories)) kcal")
                        .font(.nexusSubheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(progressColor)

                    ProgressBar(progress: progress, color: progressColor, height: 4)
                        .frame(width: 60)
                }
            } else {
                Text("No data")
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusTextTertiary)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.nexusSurface)
        }
    }

    private var progressColor: Color {
        if progress >= 1.0 { return .nexusRed }
        if progress >= 0.9 { return .nexusOrange }
        return .nexusGreen
    }
}

#Preview {
    NutritionHistoryView()
        .modelContainer(for: NutritionEntryModel.self, inMemory: true)
        .preferredColorScheme(.dark)
}
