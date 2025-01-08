import SwiftUI
import SwiftData

struct BudgetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var budget: BudgetModel
    let transactions: [TransactionModel]

    @State private var showAddExpense = false

    private var spent: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    private var remaining: Double {
        max(budget.effectiveBudget - spent, 0)
    }

    private var progress: Double {
        budget.effectiveBudget > 0 ? spent / budget.effectiveBudget : 0
    }

    private var dailyBudget: Double {
        remaining / Double(max(budget.daysRemaining, 1))
    }

    private var averageDaily: Double {
        let calendar = Calendar.current
        let daysPassed = calendar.dateComponents([.day], from: budget.currentPeriodStart, to: Date()).day ?? 1
        return spent / Double(max(daysPassed, 1))
    }

    private var projectedTotal: Double {
        averageDaily * Double(budget.daysRemaining) + spent
    }

    private var plannedExpenses: [PlannedExpenseModel] {
        budget.plannedExpenses ?? []
    }

    private var plannedTotal: Double {
        plannedExpenses.reduce(0) { $0 + $1.amount }
    }

    private var paidTotal: Double {
        plannedExpenses.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    private var categoryColor: Color {
        switch budget.category.color {
        case "orange": .nexusOrange
        case "blue": .nexusBlue
        case "pink": .nexusPink
        case "purple": .nexusPurple
        case "red": .nexusRed
        case "yellow": .yellow
        case "brown": .brown
        case "indigo": .indigo
        case "teal": .nexusTeal
        case "green": .nexusGreen
        case "mint": .mint
        case "cyan": .cyan
        default: .nexusPurple
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    progressCard
                    statsGrid
                    plannedExpensesSection
                    projectionCard
                    transactionsSection
                }
                .padding(20)
            }
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

// MARK: - Header Section

private extension BudgetDetailView {
    var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: budget.category.icon)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background {
                    Circle().fill(categoryColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(budget.category.rawValue.capitalized)
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)

                Text(formatCurrency(budget.effectiveBudget))
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(budget.period.displayName + " Budget")
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }
}

// MARK: - Progress Card

private extension BudgetDetailView {
    var progressCard: some View {
        VStack(spacing: 20) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spent")
                        .font(.nexusCaption)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(formatCurrency(spent))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                LargeProgressRing(
                    progress: progress,
                    color: categoryColor,
                    size: 100
                )
            }

            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.2))

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(width: geometry.size.width * min(progress, 1.0))

                        if budget.alertThreshold < 1.0 {
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 2)
                                .offset(x: geometry.size.width * budget.alertThreshold)
                        }
                    }
                }
                .frame(height: 16)

                HStack {
                    Text(formatCurrency(0))
                        .font(.nexusCaption2)
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer()

                    if budget.alertThreshold < 1.0 {
                        Text("Alert: \(Int(budget.alertThreshold * 100))%")
                            .font(.nexusCaption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    Text(formatCurrency(budget.effectiveBudget))
                        .font(.nexusCaption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(24)
        .background {
            ConcentricRectangleBackground(
                cornerRadius: 24,
                layers: 6,
                baseColor: categoryColor,
                spacing: 6
            )
        }
    }
}

// MARK: - Planned Expenses Section

private extension BudgetDetailView {
    var plannedExpensesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.clipboard")
                    .foregroundStyle(Color.nexusPurple)
                Text("Planned Expenses")
                    .font(.nexusHeadline)

                Spacer()

                Button {
                    showAddExpense = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.nexusPurple)
                }
            }

            if plannedExpenses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)

                    Text("No planned expenses")
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)

                    Text("Add recurring expenses like subscriptions to track your budget allocation")
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)

                    Button {
                        showAddExpense = true
                    } label: {
                        Text("Add Expense")
                            .font(.nexusSubheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background {
                                Capsule().fill(Color.nexusPurple)
                            }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                PlannedExpensesSummaryCard(
                    plannedTotal: plannedTotal,
                    paidTotal: paidTotal,
                    budgetAmount: budget.effectiveBudget
                )

                LazyVStack(spacing: 8) {
                    ForEach(plannedExpenses.sorted { !$0.isPaid && $1.isPaid }) { expense in
                        PlannedExpenseRow(expense: expense) {
                            modelContext.delete(expense)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }
}

// MARK: - Stats Grid

private extension BudgetDetailView {
    var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(
                icon: "banknote",
                title: "Remaining",
                value: formatCurrency(remaining),
                subtitle: "\(Int((1 - progress) * 100))% left",
                color: remaining > 0 ? .nexusGreen : .nexusRed
            )

            statCard(
                icon: "calendar",
                title: "Days Left",
                value: "\(budget.daysRemaining)",
                subtitle: "until \(budget.currentPeriodEnd.formatted(date: .abbreviated, time: .omitted))",
                color: .nexusBlue
            )

            statCard(
                icon: "chart.bar",
                title: "Daily Limit",
                value: formatCurrency(dailyBudget),
                subtitle: "to stay on budget",
                color: .nexusPurple
            )

            statCard(
                icon: "arrow.up.right",
                title: "Avg Daily",
                value: formatCurrency(averageDaily),
                subtitle: "current pace",
                color: averageDaily <= dailyBudget ? .nexusGreen : .nexusOrange
            )
        }
    }

    func statCard(icon: String, title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.nexusHeadline)

                Text(subtitle)
                    .font(.nexusCaption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }
}

// MARK: - Projection Card

private extension BudgetDetailView {
    var projectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.nexusOrange)
                Text("Projection")
                    .font(.nexusHeadline)
            }

            HStack(spacing: 16) {
                projectionItem(
                    title: "At Current Pace",
                    value: formatCurrency(projectedTotal),
                    isOverBudget: projectedTotal > budget.effectiveBudget
                )

                Divider().frame(height: 50)

                projectionItem(
                    title: "Difference",
                    value: formatCurrency(abs(projectedTotal - budget.effectiveBudget)),
                    isOverBudget: projectedTotal > budget.effectiveBudget,
                    showSign: true
                )
            }

            if projectedTotal > budget.effectiveBudget {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.nexusOrange)

                    Text("Reduce daily spending to \(formatCurrency(remaining / Double(max(budget.daysRemaining, 1)))) to stay on budget")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.nexusOrange.opacity(0.1))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.nexusGreen)

                    Text("You're on track to finish under budget!")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.nexusGreen.opacity(0.1))
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }

    func projectionItem(title: String, value: String, isOverBudget: Bool, showSign: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)

            Text((showSign ? (isOverBudget ? "+" : "-") : "") + value)
                .font(.nexusHeadline)
                .foregroundStyle(isOverBudget ? Color.nexusRed : Color.nexusGreen)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Transactions Section

private extension BudgetDetailView {
    var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Transactions")
                    .font(.nexusHeadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(transactions.count) items")
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)
            }

            if transactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)

                    Text("No transactions yet")
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(transactions) { transaction in
                        transactionRow(transaction)
                    }
                }
            }
        }
    }

    func transactionRow(_ transaction: TransactionModel) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(categoryColor.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: transaction.category.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(categoryColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title)
                    .font(.nexusSubheadline)

                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCurrency(transaction.amount))
                .font(.nexusHeadline)
                .foregroundStyle(Color.nexusRed)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
        }
    }
}

// MARK: - Helpers

private extension BudgetDetailView {
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = budget.currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Large Progress Ring

private struct LargeProgressRing: View {
    let progress: Double
    let color: Color
    var size: CGFloat = 100

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var ringColor: Color {
        if progress >= 1.0 { return .nexusRed }
        if progress >= 0.8 { return .nexusOrange }
        return color
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 10)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    LinearGradient(
                        colors: [ringColor, ringColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8), value: progress)

            VStack(spacing: 2) {
                Text("\(Int(clampedProgress * 100))")
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("% used")
                    .font(.system(size: size * 0.1))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
    }
}

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
    .preferredColorScheme(.dark)
}
