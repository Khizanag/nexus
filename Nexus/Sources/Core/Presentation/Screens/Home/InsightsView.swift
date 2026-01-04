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
            .background(Color.nexusBackground)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
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

    // MARK: - Productivity

    private var productivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Productivity")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            NexusCard {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Task Completion Rate")
                                .font(.nexusSubheadline)
                                .foregroundStyle(.secondary)

                            Text("\(completionRate)%")
                                .font(.nexusLargeTitle)
                                .foregroundStyle(Color.nexusGreen)
                        }

                        Spacer()

                        CircularProgressView(progress: Double(completionRate) / 100)
                            .frame(width: 60, height: 60)
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading) {
                            Text("This Week")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                            Text("\(tasksCompletedThisWeek) tasks completed")
                                .font(.nexusSubheadline)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Notes Created")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                            Text("\(notesThisWeek)")
                                .font(.nexusSubheadline)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Finance

    private var financeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finance")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            NexusCard {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("This Month")
                                .font(.nexusSubheadline)
                                .foregroundStyle(.secondary)

                            Text(formatCurrency(monthlySpending))
                                .font(.nexusTitle)
                                .foregroundStyle(monthlySpending > monthlyIncome ? Color.nexusRed : Color.nexusGreen)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(Color.nexusGreen)
                                Text(formatCurrency(monthlyIncome))
                                    .foregroundStyle(Color.nexusGreen)
                            }
                            .font(.nexusSubheadline)

                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundStyle(Color.nexusRed)
                                Text(formatCurrency(monthlyExpenses))
                                    .foregroundStyle(Color.nexusRed)
                            }
                            .font(.nexusSubheadline)
                        }
                    }

                    if !topCategories.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Top Categories")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)

                            ForEach(topCategories.prefix(3), id: \.category) { item in
                                HStack {
                                    Text(item.category.rawValue.capitalized)
                                        .font(.nexusSubheadline)
                                    Spacer()
                                    Text(formatCurrency(item.amount))
                                        .font(.nexusSubheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Health

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            if healthEntries.isEmpty {
                NexusCard {
                    VStack(spacing: 8) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No health data yet")
                            .font(.nexusSubheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
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

    // MARK: - Computed Properties

    private var completionRate: Int {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.isCompleted }.count
        return Int((Double(completed) / Double(tasks.count)) * 100)
    }

    private var tasksCompletedThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= weekAgo
        }.count
    }

    private var notesThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return notes.filter { $0.createdAt >= weekAgo }.count
    }

    private var monthlyTransactions: [TransactionModel] {
        let calendar = Calendar.current
        return transactions.filter { transaction in
            calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
    }

    private var monthlyIncome: Double {
        monthlyTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthlyExpenses: Double {
        monthlyTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthlySpending: Double {
        monthlyIncome - monthlyExpenses
    }

    private var topCategories: [(category: TransactionCategory, amount: Double)] {
        let expenses = monthlyTransactions.filter { $0.type == .expense }
        var categoryTotals: [TransactionCategory: Double] = [:]

        for expense in expenses {
            categoryTotals[expense.category, default: 0] += expense.amount
        }

        return categoryTotals
            .map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    private var latestHealthMetrics: [HealthEntryModel] {
        var latestByType: [HealthMetricType: HealthEntryModel] = [:]
        for entry in healthEntries {
            if latestByType[entry.type] == nil {
                latestByType[entry.type] = entry
            }
        }
        return Array(latestByType.values).sorted { $0.type.displayName < $1.type.displayName }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    private func formatHealthValue(_ value: Double, type: HealthMetricType) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value)) \(type.defaultUnit)"
        }
        return String(format: "%.1f %@", value, type.defaultUnit)
    }

    private func healthColor(for type: HealthMetricType) -> Color {
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
                .font(.system(size: 24))
                .foregroundStyle(color)

            Text(value)
                .font(.nexusTitle2)

            Text(title)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }
}

private struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.nexusBorder, lineWidth: 6)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.nexusGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.nexusGreen)
        }
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
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(.nexusHeadline)

            Text(title)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }
}

#Preview {
    InsightsView()
        .preferredColorScheme(.dark)
}
