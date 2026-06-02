import Charts
import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \NoteModel.updatedAt, order: .reverse)
    private var notes: [NoteModel]

    @Query(sort: \TaskModel.createdAt, order: .reverse)
    private var tasks: [TaskModel]

    @Query(sort: \TransactionModel.date, order: .reverse)
    private var transactions: [TransactionModel]

    @Query(sort: \HealthEntryModel.date, order: .reverse)
    private var healthEntries: [HealthEntryModel]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    overviewSection
                    productivitySection
                    financeSection
                    healthSection
                }
                .padding(20)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(Color.nexusBackground)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Overview

private extension InsightsView {
    var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                StatCard(
                    title: "Notes",
                    value: "\(notes.count)",
                    icon: "doc.text.fill",
                    color: .notesColor
                )

                StatCard(
                    title: "Tasks",
                    value: "\(tasks.count)",
                    icon: "checkmark.circle.fill",
                    color: .tasksColor
                )

                StatCard(
                    title: "Done",
                    value: "\(tasks.filter { $0.isCompleted }.count)",
                    icon: "checkmark.seal.fill",
                    color: .nexusGreen
                )
            }
        }
    }
}

// MARK: - Productivity

private extension InsightsView {
    var productivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Productivity")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            NexusCard {
                VStack(spacing: 16) {
                    completionRateRow
                    Divider()
                    weeklyStatsRow
                }
            }
        }
    }

    var completionRateRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Task Completion Rate")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)

                Text("\(completionRate)%")
                    .font(.nexusLargeTitle)
                    .foregroundStyle(Color.nexusGreen)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Task completion rate: \(completionRate) percent")

            Spacer()

            Gauge(value: Double(completionRate), in: 0...100) {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.nexusGreen)
            } currentValueLabel: {
                Text("\(completionRate)")
                    .font(.nexusCaption2)
                    .foregroundStyle(Color.nexusGreen)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Color.nexusGreen)
            .frame(width: 60, height: 60)
            .accessibilityHidden(true)
        }
    }

    var weeklyStatsRow: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("This Week")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
                Text("\(tasksCompletedThisWeek) tasks completed")
                    .font(.nexusSubheadline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("This week: \(tasksCompletedThisWeek) tasks completed")

            Spacer()

            VStack(alignment: .trailing) {
                Text("Notes Created")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
                Text("\(notesThisWeek)")
                    .font(.nexusSubheadline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Notes created this week: \(notesThisWeek)")
        }
    }
}

// MARK: - Finance

private extension InsightsView {
    var financeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finance")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            NexusCard {
                VStack(spacing: 16) {
                    financeHeaderRow

                    if !topCategories.isEmpty {
                        Divider()
                        financeCategoriesRows
                    }
                }
            }
        }
    }

    var financeHeaderRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("This Month")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)

                Text(formatCurrency(monthlySpending))
                    .font(.nexusTitle)
                    .foregroundStyle(monthlySpending > monthlyIncome ? Color.nexusRed : Color.nexusGreen)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("This month net: \(formatCurrency(monthlySpending))")

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Color.nexusGreen)
                        .accessibilityHidden(true)
                    Text(formatCurrency(monthlyIncome))
                        .foregroundStyle(Color.nexusGreen)
                }
                .font(.nexusSubheadline)
                .accessibilityLabel("Income: \(formatCurrency(monthlyIncome))")

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(Color.nexusRed)
                        .accessibilityHidden(true)
                    Text(formatCurrency(monthlyExpenses))
                        .foregroundStyle(Color.nexusRed)
                }
                .font(.nexusSubheadline)
                .accessibilityLabel("Expenses: \(formatCurrency(monthlyExpenses))")
            }
        }
    }

    var financeCategoriesRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Categories")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)

            ForEach(topCategories.prefix(3), id: \.category) { item in
                let fraction = monthlyExpenses > 0 ? item.amount / monthlyExpenses : 0
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.category.rawValue.capitalized)
                            .font(.nexusSubheadline)
                        Spacer()
                        Text(formatCurrency(item.amount))
                            .font(.nexusSubheadline)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: fraction)
                        .tint(Color.financeColor)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item.category.rawValue.capitalized): \(formatCurrency(item.amount))")
            }
        }
    }
}

// MARK: - Health

private extension InsightsView {
    var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            if healthEntries.isEmpty {
                ContentUnavailableView(
                    "No Health Data",
                    systemImage: "heart.text.square",
                    description: Text("Start tracking your health metrics")
                )
                .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    ForEach(latestHealthMetrics, id: \.type) { metric in
                        HealthMetricCard(
                            title: metric.type.displayName,
                            value: formatHealthValue(metric.value, type: metric.type),
                            icon: metric.type.icon,
                            color: healthColor(for: metric.type)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Computed Properties

private extension InsightsView {
    var completionRate: Int {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.isCompleted }.count
        return Int((Double(completed) / Double(tasks.count)) * 100)
    }

    var tasksCompletedThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= weekAgo
        }.count
    }

    var notesThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return notes.filter { $0.createdAt >= weekAgo }.count
    }

    var monthlyTransactions: [TransactionModel] {
        let calendar = Calendar.current
        return transactions.filter { transaction in
            calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
    }

    var monthlyIncome: Double {
        monthlyTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    var monthlyExpenses: Double {
        monthlyTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    var monthlySpending: Double {
        monthlyIncome - monthlyExpenses
    }

    var topCategories: [(category: TransactionCategory, amount: Double)] {
        let expenses = monthlyTransactions.filter { $0.type == .expense }
        var categoryTotals: [TransactionCategory: Double] = [:]

        for expense in expenses {
            categoryTotals[expense.category, default: 0] += expense.amount
        }

        return categoryTotals
            .map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    var latestHealthMetrics: [HealthEntryModel] {
        var latestByType: [HealthMetricType: HealthEntryModel] = [:]
        for entry in healthEntries {
            if latestByType[entry.type] == nil {
                latestByType[entry.type] = entry
            }
        }
        return Array(latestByType.values).sorted { $0.type.displayName < $1.type.displayName }
    }

    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    func formatHealthValue(_ value: Double, type: HealthMetricType) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value)) \(type.defaultUnit)"
        }
        return String(format: "%.1f %@", value, type.defaultUnit)
    }

    func healthColor(for type: HealthMetricType) -> Color {
        switch type.color {
        case "purple": .nexusPurple
        case "blue": .nexusBlue
        case "indigo": .indigo
        case "green": .nexusGreen
        case "orange": .nexusOrange
        case "red": .nexusRed
        case "pink": .nexusPink
        case "yellow": .yellow
        case "teal": .nexusTeal
        default: .secondary
        }
    }
}

// MARK: - Supporting Views

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.nexusTitle2)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(value)
                .font(.nexusTitle2)

            Text(title)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassBackground(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct HealthMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.nexusTitle3)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(value)
                .font(.nexusHeadline)

            Text(title)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassBackground(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Preview

#Preview {
    InsightsView()
}
