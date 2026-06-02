import SwiftUI
import SwiftData
import Charts

struct BudgetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var budget: BudgetModel
    let transactions: [TransactionModel]

    @State private var showAddExpense = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                progressSection
                statsSection
                projectionSection
                plannedExpensesSection
                transactionsSection
            }
            .listStyle(.insetGrouped)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(Color.nexusBackground)
            .navigationTitle(budget.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAddExpense) {
                AddPlannedExpenseSheet(budget: budget)
            }
        }
    }
}

// MARK: - Progress Section

private extension BudgetDetailView {
    var progressSection: some View {
        Section {
            GlassCard(tint: categoryColor) {
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                            Text("Spent")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                            Text(spent.formatted(.currency(code: budget.currency)))
                                .font(.nexusDisplayNumber(.title))
                        }
                        Spacer()
                        BudgetProgressGauge(
                            progress: progress,
                            currency: budget.currency,
                            spent: spent,
                            total: budget.effectiveBudget,
                            size: 80
                        )
                    }

                    utilizationChart
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }

    var utilizationChart: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Chart {
                BarMark(
                    x: .value("Spent", spent),
                    y: .value("Type", "Spent")
                )
                .foregroundStyle(progressColor)
                .cornerRadius(DesignSystem.CornerRadius.sm)

                BarMark(
                    x: .value("Remaining", max(budget.effectiveBudget - spent, 0)),
                    y: .value("Type", "Spent")
                )
                .foregroundStyle(Color.secondary.opacity(0.25))
                .cornerRadius(DesignSystem.CornerRadius.sm)

                if budget.alertThreshold < 1.0 {
                    RuleMark(x: .value("Alert", budget.effectiveBudget * budget.alertThreshold))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .foregroundStyle(Color.nexusOrange)
                        .annotation(position: .top, alignment: .center) {
                            Text("\(Int(budget.alertThreshold * 100))%")
                                .font(.nexusCaption2)
                                .foregroundStyle(Color.nexusOrange)
                        }
                }
            }
            .chartXScale(domain: 0...max(budget.effectiveBudget, spent))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 28)
            .accessibilityLabel("Spending bar: \(spent.formatted(.currency(code: budget.currency))) of \(budget.effectiveBudget.formatted(.currency(code: budget.currency)))")

            HStack {
                Text(0.formatted(.currency(code: budget.currency).precision(.fractionLength(0))))
                    .font(.nexusCaption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if budget.alertThreshold < 1.0 {
                    Text("Alert: \(Int(budget.alertThreshold * 100))%")
                        .font(.nexusCaption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(budget.effectiveBudget.formatted(.currency(code: budget.currency).precision(.fractionLength(0))))
                    .font(.nexusCaption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Stats Section

private extension BudgetDetailView {
    var statsSection: some View {
        Section("Statistics") {
            LabeledContent("Remaining") {
                Text(remaining.formatted(.currency(code: budget.currency)))
                    .foregroundStyle(remaining > 0 ? Color.nexusGreen : Color.nexusRed)
                    .fontWeight(.medium)
            }
            .listRowBackground(Color.nexusSurface)

            LabeledContent("Days Left") {
                Text("\(budget.daysRemaining) days")
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.nexusSurface)

            LabeledContent("Daily Limit") {
                Text(dailyBudget.formatted(.currency(code: budget.currency)))
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.nexusSurface)

            LabeledContent("Avg Daily Spend") {
                Text(averageDaily.formatted(.currency(code: budget.currency)))
                    .foregroundStyle(averageDaily <= dailyBudget ? Color.nexusGreen : Color.nexusOrange)
                    .fontWeight(.medium)
            }
            .listRowBackground(Color.nexusSurface)

            LabeledContent("Period End") {
                Text(budget.currentPeriodEnd.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.nexusSurface)
        }
    }
}

// MARK: - Projection Section

private extension BudgetDetailView {
    var projectionSection: some View {
        Section("Projection") {
            LabeledContent("At Current Pace") {
                Text(projectedTotal.formatted(.currency(code: budget.currency)))
                    .foregroundStyle(projectedTotal > budget.effectiveBudget ? Color.nexusRed : Color.nexusGreen)
                    .fontWeight(.medium)
            }
            .listRowBackground(Color.nexusSurface)

            LabeledContent("Difference") {
                let diff = abs(projectedTotal - budget.effectiveBudget)
                let over = projectedTotal > budget.effectiveBudget
                Text((over ? "+" : "-") + diff.formatted(.currency(code: budget.currency)))
                    .foregroundStyle(over ? Color.nexusRed : Color.nexusGreen)
                    .fontWeight(.medium)
            }
            .listRowBackground(Color.nexusSurface)

            if projectedTotal > budget.effectiveBudget {
                Label {
                    Text("Reduce daily spending to \(dailyBudget.formatted(.currency(code: budget.currency))) to stay on budget")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.nexusOrange)
                }
                .listRowBackground(Color.nexusOrange.opacity(0.08))
            } else {
                Label {
                    Text("You're on track to finish under budget")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.nexusGreen)
                }
                .listRowBackground(Color.nexusGreen.opacity(0.08))
            }
        }
    }
}

// MARK: - Planned Expenses Section

private extension BudgetDetailView {
    var plannedExpensesSection: some View {
        Section {
            if plannedExpenses.isEmpty {
                ContentUnavailableView {
                    Label("No Planned Expenses", systemImage: "checklist")
                } description: {
                    Text("Add recurring expenses like subscriptions to track budget allocation.")
                } actions: {
                    Button("Add Expense") { showAddExpense = true }
                        .buttonStyle(.glass)
                }
                .listRowBackground(Color.nexusSurface)
            } else {
                PlannedExpensesSummaryCard(
                    plannedTotal: plannedTotal,
                    paidTotal: paidTotal,
                    budgetAmount: budget.effectiveBudget
                )
                .listRowBackground(Color.nexusSurface)

                ForEach(plannedExpenses.sorted { !$0.isPaid && $1.isPaid }) { expense in
                    PlannedExpenseRow(expense: expense) {
                        modelContext.delete(expense)
                    }
                    .listRowBackground(Color.nexusSurface)
                }
            }
        } header: {
            HStack {
                Text("Planned Expenses")
                Spacer()
                Button {
                    showAddExpense = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.nexusPurple)
                }
                .accessibilityLabel("Add planned expense")
            }
        }
    }
}

// MARK: - Transactions Section

private extension BudgetDetailView {
    var transactionsSection: some View {
        Section {
            if transactions.isEmpty {
                ContentUnavailableView("No Transactions", systemImage: "tray")
                    .listRowBackground(Color.nexusSurface)
            } else {
                ForEach(transactions) { transaction in
                    transactionRow(transaction)
                        .listRowBackground(Color.nexusSurface)
                }
            }
        } header: {
            HStack {
                Text("Transactions")
                Spacer()
                Text("\(transactions.count) items")
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    func transactionRow(_ transaction: TransactionModel) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: transaction.category.icon)
                .font(.nexusSubheadline)
                .foregroundStyle(categoryColor)
                .frame(width: DesignSystem.Size.Avatar.sm, height: DesignSystem.Size.Avatar.sm)
                .background(categoryColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title)
                    .font(.nexusSubheadline)
                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(transaction.amount.formatted(.currency(code: budget.currency)))
                .font(.nexusHeadline)
                .foregroundStyle(Color.nexusRed)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transaction.title), \(transaction.amount.formatted(.currency(code: budget.currency))), \(transaction.date.formatted(date: .abbreviated, time: .omitted))")
    }
}

// MARK: - Computed Properties

private extension BudgetDetailView {
    var spent: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    var remaining: Double {
        max(budget.effectiveBudget - spent, 0)
    }

    var progress: Double {
        budget.effectiveBudget > 0 ? spent / budget.effectiveBudget : 0
    }

    var dailyBudget: Double {
        remaining / Double(max(budget.daysRemaining, 1))
    }

    var averageDaily: Double {
        let calendar = Calendar.current
        let daysPassed = calendar.dateComponents([.day], from: budget.currentPeriodStart, to: Date()).day ?? 1
        return spent / Double(max(daysPassed, 1))
    }

    var projectedTotal: Double {
        averageDaily * Double(budget.daysRemaining) + spent
    }

    var plannedExpenses: [PlannedExpenseModel] {
        budget.plannedExpenses ?? []
    }

    var plannedTotal: Double {
        plannedExpenses.reduce(0) { $0 + $1.amount }
    }

    var paidTotal: Double {
        plannedExpenses.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    var categoryColor: Color {
        TransactionCategoryColorMapper.color(for: budget.category.color)
    }

    var progressColor: Color {
        if progress >= 1.0 { return .nexusRed }
        if progress >= budget.alertThreshold { return .nexusOrange }
        return .nexusGreen
    }
}

// MARK: - Preview

#Preview {
    BudgetDetailView(
        budget: BudgetModel(
            name: "Food Budget",
            amount: 500,
            category: .food,
            period: .monthly
        ),
        transactions: []
    )
}
