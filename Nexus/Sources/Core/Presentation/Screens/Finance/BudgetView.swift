import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetModel.createdAt, order: .reverse) private var budgets: [BudgetModel]
    @Query(sort: \TransactionModel.date, order: .reverse) private var transactions: [TransactionModel]

    @AppStorage("currency") private var preferredCurrency = "USD"

    private let currencyService: CurrencyServiceProtocol = CurrencyService()

    @State private var showAddBudget = false
    @State private var selectedBudget: BudgetModel?
    @State private var showBudgetDetail: BudgetModel?
    @State private var budgetToDelete: BudgetModel?
    @State private var exchangeRates: ExchangeRates?

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 24) {
                if budgets.isEmpty {
                    emptyState
                } else {
                    overviewCard
                    activeBudgets
                    if !completedBudgets.isEmpty {
                        completedBudgetsSection
                    }
                    insightsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.nexusBackground)
        .navigationTitle("Budgets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddBudget = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddBudget) {
            BudgetEditorView(budget: nil)
        }
        .sheet(item: $selectedBudget) { budget in
            BudgetEditorView(budget: budget)
        }
        .sheet(item: $showBudgetDetail) { budget in
            BudgetDetailView(budget: budget, transactions: transactionsForBudget(budget))
        }
        .alert("Delete Budget", isPresented: .init(
            get: { budgetToDelete != nil },
            set: { if !$0 { budgetToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { budgetToDelete = nil }
            Button("Delete", role: .destructive) {
                if let budget = budgetToDelete {
                    modelContext.delete(budget)
                }
                budgetToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete \"\(budgetToDelete?.name ?? "this budget")\"? This action cannot be undone.")
        }
        .task {
            await fetchExchangeRates()
        }
        .onChange(of: preferredCurrency) {
            Task { await fetchExchangeRates() }
        }
        }
    }

    private func fetchExchangeRates() async {
        guard let baseCurrency = Currency(rawValue: preferredCurrency) else { return }
        do {
            exchangeRates = try await currencyService.fetchRatesFromAPI(base: baseCurrency)
        } catch {
            print("Failed to fetch rates: \(error)")
        }
    }

    private var activeBudgetsList: [BudgetModel] {
        budgets.filter { $0.isActive }
    }

    private var completedBudgets: [BudgetModel] {
        budgets.filter { !$0.isActive }
    }

    private func transactionsForBudget(_ budget: BudgetModel) -> [TransactionModel] {
        transactions.filter { transaction in
            transaction.type == .expense &&
            transaction.category == budget.category &&
            transaction.date >= budget.currentPeriodStart &&
            transaction.date <= budget.currentPeriodEnd
        }
    }

    private func spentAmount(for budget: BudgetModel) -> Double {
        transactionsForBudget(budget).reduce(0) { $0 + $1.amount }
    }

    private func convertedSpentAmount(for budget: BudgetModel) -> Double {
        transactionsForBudget(budget).reduce(0) { $0 + convertToBase($1.amount, from: $1.currency) }
    }

    private func budgetStatus(for budget: BudgetModel) -> BudgetStatus {
        let spent = spentAmount(for: budget)
        let ratio = spent / budget.effectiveBudget

        if ratio >= 1.0 { return .exceeded }
        if ratio >= budget.alertThreshold { return .warning }
        return .onTrack
    }
}

// MARK: - Empty State

private extension BudgetView {
    var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)

            ConcentricCard(color: .nexusPurple) {
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)

                    Text("No Budgets Yet")
                        .font(.nexusTitle2)
                        .foregroundStyle(.white)

                    Text("Create budgets to track your spending\nand stay on top of your finances")
                        .font(.nexusSubheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            ConcentricButton("Create Your First Budget", icon: "plus.circle.fill", color: .nexusPurple) {
                showAddBudget = true
            }

            suggestedBudgetsSection

            Spacer()
        }
    }

    var suggestedBudgetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suggested Budgets")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                suggestedBudgetCard(category: .food, amount: 500)
                suggestedBudgetCard(category: .transport, amount: 200)
                suggestedBudgetCard(category: .entertainment, amount: 150)
                suggestedBudgetCard(category: .shopping, amount: 300)
            }
        }
        .padding(.top, 20)
    }

    func suggestedBudgetCard(category: TransactionCategory, amount: Double) -> some View {
        Button {
            createBudget(category: category, amount: amount)
        } label: {
            VStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(categoryColor(category))

                Text(category.rawValue.capitalized)
                    .font(.nexusSubheadline)

                Text("$\(Int(amount))/mo")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    func createBudget(category: TransactionCategory, amount: Double) {
        let budget = BudgetModel(
            name: "\(category.rawValue.capitalized) Budget",
            amount: amount,
            category: category,
            colorHex: category.color
        )
        modelContext.insert(budget)
    }
}

// MARK: - Overview Card

private extension BudgetView {
    var overviewCard: some View {
        let totalBudget = activeBudgetsList.reduce(0) { $0 + convertToBase($1.effectiveBudget, from: $1.currency) }
        let totalSpent = activeBudgetsList.reduce(0) { $0 + convertedSpentAmount(for: $1) }
        let remaining = totalBudget - totalSpent
        let progress = totalBudget > 0 ? totalSpent / totalBudget : 0

        return VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Budget")
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)

                    Text(formatCurrency(totalBudget))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }

                Spacer()

                BudgetProgressRing(progress: progress, size: 80, lineWidth: 8)
            }

            HStack(spacing: 20) {
                overviewStat(
                    title: "Spent",
                    value: formatCurrency(totalSpent),
                    color: .nexusRed
                )

                Divider().frame(height: 40)

                overviewStat(
                    title: "Remaining",
                    value: formatCurrency(remaining),
                    color: remaining >= 0 ? .nexusGreen : .nexusRed
                )

                Divider().frame(height: 40)

                overviewStat(
                    title: "Budgets",
                    value: "\(activeBudgetsList.count)",
                    color: .nexusPurple
                )
            }
        }
        .padding(20)
        .background {
            ConcentricRectangleBackground(
                cornerRadius: 24,
                layers: 5,
                baseColor: .nexusPurple,
                spacing: 5
            )
        }
    }

    func overviewStat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.nexusCaption)
                .foregroundStyle(.white.opacity(0.7))

            Text(value)
                .font(.nexusHeadline)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Active Budgets

private extension BudgetView {
    var activeBudgets: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Budgets")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            LazyVStack(spacing: 12) {
                ForEach(activeBudgetsList) { budget in
                    BudgetCard(
                        budget: budget,
                        spent: spentAmount(for: budget),
                        status: budgetStatus(for: budget),
                        onTap: { showBudgetDetail = budget },
                        onEdit: { selectedBudget = budget },
                        onDelete: { budgetToDelete = budget }
                    )
                }
            }
        }
    }
}

// MARK: - Completed Budgets

private extension BudgetView {
    var completedBudgetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inactive Budgets")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            ForEach(completedBudgets) { budget in
                HStack(spacing: 12) {
                    Image(systemName: budget.category.icon)
                        .foregroundStyle(.secondary)

                    Text(budget.name)
                        .font(.nexusSubheadline)

                    Spacer()

                    Button("Activate") {
                        budget.isActive = true
                    }
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusPurple)
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.nexusSurface)
                }
            }
        }
    }
}

// MARK: - Insights Section

private extension BudgetView {
    var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                insightCard(
                    icon: "chart.bar.fill",
                    title: "Best Category",
                    value: bestPerformingCategory?.rawValue.capitalized ?? "N/A",
                    color: .nexusGreen
                )

                insightCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "Needs Attention",
                    value: worstPerformingCategory?.rawValue.capitalized ?? "All Good!",
                    color: worstPerformingCategory != nil ? .nexusOrange : .nexusGreen
                )

                insightCard(
                    icon: "calendar",
                    title: "Days Left",
                    value: "\(activeBudgetsList.first?.daysRemaining ?? 0)",
                    color: .nexusBlue
                )

                insightCard(
                    icon: "percent",
                    title: "Avg Utilization",
                    value: String(format: "%.0f%%", averageUtilization * 100),
                    color: .nexusPurple
                )
            }
        }
    }

    var bestPerformingCategory: TransactionCategory? {
        activeBudgetsList
            .filter { spentAmount(for: $0) < $0.effectiveBudget * 0.5 }
            .min { spentAmount(for: $0) / $0.effectiveBudget < spentAmount(for: $1) / $1.effectiveBudget }?
            .category
    }

    var worstPerformingCategory: TransactionCategory? {
        activeBudgetsList
            .filter { spentAmount(for: $0) >= $0.effectiveBudget * 0.8 }
            .max { spentAmount(for: $0) / $0.effectiveBudget < spentAmount(for: $1) / $1.effectiveBudget }?
            .category
    }

    var averageUtilization: Double {
        guard !activeBudgetsList.isEmpty else { return 0 }
        let total = activeBudgetsList.reduce(0.0) { $0 + (spentAmount(for: $1) / $1.effectiveBudget) }
        return total / Double(activeBudgetsList.count)
    }

    func insightCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.nexusHeadline)
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

// MARK: - Helpers

private extension BudgetView {
    var baseCurrency: Currency {
        Currency(rawValue: preferredCurrency) ?? .usd
    }

    func convertToBase(_ amount: Double, from currencyCode: String) -> Double {
        guard let fromCurrency = Currency(rawValue: currencyCode),
              let rates = exchangeRates else { return amount }
        return currencyService.convert(amount: amount, from: fromCurrency, to: baseCurrency, rates: rates)
    }

    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = preferredCurrency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    func categoryColor(_ category: TransactionCategory) -> Color {
        TransactionCategoryColorMapper.color(for: category.color)
    }
}

#Preview {
    BudgetView()
        .preferredColorScheme(.dark)
}
