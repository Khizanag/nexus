import SwiftUI
import SwiftData
import Charts

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetModel.createdAt, order: .reverse) private var budgets: [BudgetModel]
    @Query(sort: \TransactionModel.date, order: .reverse) private var transactions: [TransactionModel]

    @AppStorage("currency") private var preferredCurrency = "USD"

    private let currencyService: CurrencyService = DefaultCurrencyService()

    @State private var showAddBudget = false
    @State private var selectedBudget: BudgetModel?
    @State private var showBudgetDetail: BudgetModel?
    @State private var budgetToDelete: BudgetModel?
    @State private var exchangeRates: ExchangeRates?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if budgets.isEmpty {
                    emptyContent
                } else {
                    listContent
                }
            }
            .background(Color.nexusBackground)
            .navigationTitle("Budgets")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAddBudget) { BudgetEditorView(budget: nil) }
            .sheet(item: $selectedBudget) { BudgetEditorView(budget: $0) }
            .sheet(item: $showBudgetDetail) { budget in
                BudgetDetailView(budget: budget, transactions: transactionsForBudget(budget))
            }
            .alert("Delete Budget", isPresented: deleteAlertBinding) {
                Button("Cancel", role: .cancel) { budgetToDelete = nil }
                Button("Delete", role: .destructive) { deleteBudget() }
            } message: {
                Text("Are you sure you want to delete \"\(budgetToDelete?.name ?? "this budget")\"? This action cannot be undone.")
            }
            .task { await fetchExchangeRates() }
            .onChange(of: preferredCurrency) { Task { await fetchExchangeRates() } }
        }
    }
}

// MARK: - Toolbar

private extension BudgetView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            GlassIconButton(systemImage: "plus", accessibilityLabel: "Add Budget") {
                showAddBudget = true
            }
        }
    }
}

// MARK: - Empty Content

private extension BudgetView {
    var emptyContent: some View {
        ContentUnavailableView {
            Label("No Budgets Yet", systemImage: "chart.pie.fill")
        } description: {
            Text("Create budgets to track your spending and stay on top of your finances.")
        } actions: {
            suggestedActions
        }
    }

    @ViewBuilder
    var suggestedActions: some View {
        Button("Create Budget") {
            showAddBudget = true
        }
        .buttonStyle(.glassProminent)

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Suggested")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
                .padding(.top, DesignSystem.Spacing.md)

            GlassEffectContainer(spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(suggestedBudgetItems, id: \.0) { category, amount in
                        Button {
                            createBudget(category: category, amount: amount)
                        } label: {
                            VStack(spacing: DesignSystem.Spacing.xxs) {
                                Image(systemName: category.icon)
                                    .font(.nexusSubheadline)
                                    .foregroundStyle(TransactionCategoryColorMapper.color(for: category.color))
                                Text(category.rawValue.capitalized)
                                    .font(.nexusCaption2)
                                Text(amount.formatted(.currency(code: preferredCurrency).precision(.fractionLength(0))))
                                    .font(.nexusCaption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("\(category.rawValue.capitalized), \(amount.formatted(.currency(code: preferredCurrency))) per month")
                    }
                }
            }
        }
    }

    var suggestedBudgetItems: [(TransactionCategory, Double)] {
        [(.food, 500), (.transport, 200), (.entertainment, 150), (.shopping, 300)]
    }
}

// MARK: - List Content

private extension BudgetView {
    var listContent: some View {
        List {
            overviewSection
            if !activeBudgetsList.isEmpty {
                activeSection
            }
            if !completedBudgets.isEmpty {
                inactiveSection
            }
            insightsSection
        }
        .listStyle(.insetGrouped)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    // MARK: Overview

    var overviewSection: some View {
        Section {
            let totalBudget = activeBudgetsList.reduce(0) { $0 + convertToBase($1.effectiveBudget, from: $1.currency) }
            let totalSpent = activeBudgetsList.reduce(0) { $0 + convertedSpentAmount(for: $1) }
            let remaining = totalBudget - totalSpent
            let progress = totalBudget > 0 ? totalSpent / totalBudget : 0

            GlassCard(tint: .nexusPurple) {
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                            Text("Total Budget")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                            Text(totalBudget.formatted(.currency(code: preferredCurrency).precision(.fractionLength(0))))
                                .font(.nexusDisplayNumber(.title))
                        }
                        Spacer()
                        Gauge(value: min(progress, 1)) {
                            EmptyView()
                        } currentValueLabel: {
                            Text("\(Int(progress * 100))%")
                                .font(.nexusCaption)
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(progressTint(progress))
                        .frame(width: 60, height: 60)
                        .accessibilityLabel("Budget usage \(Int(progress * 100)) percent")
                    }

                    HStack(spacing: DesignSystem.Spacing.lg) {
                        overviewStat(
                            title: "Spent",
                            value: totalSpent.formatted(.currency(code: preferredCurrency).precision(.fractionLength(0))),
                            color: .nexusRed
                        )
                        Divider().frame(height: 36)
                        overviewStat(
                            title: "Remaining",
                            value: remaining.formatted(.currency(code: preferredCurrency).precision(.fractionLength(0))),
                            color: remaining >= 0 ? .nexusGreen : .nexusRed
                        )
                        Divider().frame(height: 36)
                        overviewStat(
                            title: "Active",
                            value: "\(activeBudgetsList.count)",
                            color: .nexusPurple
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }

    func overviewStat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text(title)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.nexusSubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    // MARK: Active Section

    var activeSection: some View {
        Section("Active") {
            ForEach(activeBudgetsList) { budget in
                BudgetListRow(
                    budget: budget,
                    spent: spentAmount(for: budget),
                    status: budgetStatus(for: budget),
                    currency: budget.currency
                )
                .contentShape(.rect)
                .onTapGesture { showBudgetDetail = budget }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        budgetToDelete = budget
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        selectedBudget = budget
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.nexusBlue)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        budget.isActive = false
                    } label: {
                        Label("Deactivate", systemImage: "pause.circle")
                    }
                    .tint(.nexusOrange)
                }
                .listRowBackground(Color.nexusSurface)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Double tap to view details")
            }
        }
    }

    // MARK: Inactive Section

    var inactiveSection: some View {
        Section("Inactive") {
            ForEach(completedBudgets) { budget in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: budget.category.icon)
                        .foregroundStyle(TransactionCategoryColorMapper.color(for: budget.category.color))
                        .frame(width: DesignSystem.Size.Icon.md, alignment: .center)
                        .accessibilityHidden(true)

                    Text(budget.name)
                        .font(.nexusSubheadline)

                    Spacer()

                    Text(budget.period.displayName)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        budget.isActive = true
                    } label: {
                        Label("Activate", systemImage: "play.circle")
                    }
                    .tint(.nexusGreen)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        budgetToDelete = budget
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowBackground(Color.nexusSurface)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(budget.name), \(budget.period.displayName), inactive")
                .accessibilityHint("Swipe right to activate")
            }
        }
    }

    // MARK: Insights Section

    var insightsSection: some View {
        Section("Insights") {
            if !activeBudgetsList.isEmpty {
                utilizationChart
                    .listRowBackground(Color.nexusSurface)
                    .listRowInsets(.init(top: DesignSystem.Spacing.sm, leading: DesignSystem.Spacing.md, bottom: DesignSystem.Spacing.sm, trailing: DesignSystem.Spacing.md))
            }

            LabeledContent("Best Category", value: bestPerformingCategory?.rawValue.capitalized ?? "N/A")
                .font(.nexusSubheadline)
                .listRowBackground(Color.nexusSurface)

            LabeledContent("Needs Attention", value: worstPerformingCategory?.rawValue.capitalized ?? "All Good")
                .font(.nexusSubheadline)
                .listRowBackground(Color.nexusSurface)

            LabeledContent("Avg Utilization", value: averageUtilization.formatted(.percent.precision(.fractionLength(0))))
                .font(.nexusSubheadline)
                .listRowBackground(Color.nexusSurface)
        }
    }

    var utilizationChart: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Budget Utilization")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)

            Chart {
                ForEach(activeBudgetsList) { budget in
                    let spent = spentAmount(for: budget)
                    let utilization = budget.effectiveBudget > 0 ? spent / budget.effectiveBudget : 0

                    BarMark(
                        x: .value("Budget", budget.name),
                        y: .value("Utilization", min(utilization, 1.2))
                    )
                    .foregroundStyle(chartBarColor(for: budgetStatus(for: budget)))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                    .accessibilityLabel("\(budget.name): \(utilization.formatted(.percent.precision(.fractionLength(0))))")
                }

                RuleMark(y: .value("Alert Threshold", activeBudgetsList.first?.alertThreshold ?? 0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(Color.nexusOrange)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("Alert")
                            .font(.nexusCaption2)
                            .foregroundStyle(Color.nexusOrange)
                    }
            }
            .chartYScale(domain: 0...1.2)
            .chartYAxis {
                AxisMarks(values: [0, 0.5, 1.0]) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.formatted(.percent.precision(.fractionLength(0))))
                                .font(.nexusCaption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .frame(height: 160)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Budget utilization chart")
    }

    func chartBarColor(for status: BudgetStatus) -> Color {
        switch status {
        case .onTrack: .nexusGreen
        case .warning: .nexusOrange
        case .exceeded: .nexusRed
        case .completed: .nexusBlue
        }
    }

    func progressTint(_ progress: Double) -> Color {
        if progress >= 1.0 { return .nexusRed }
        if progress >= 0.8 { return .nexusOrange }
        return .nexusGreen
    }
}

// MARK: - Computed Properties

private extension BudgetView {
    var activeBudgetsList: [BudgetModel] {
        budgets.filter { $0.isActive }
    }

    var completedBudgets: [BudgetModel] {
        budgets.filter { !$0.isActive }
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

    var baseCurrency: Currency {
        Currency(rawValue: preferredCurrency) ?? .usd
    }

    var deleteAlertBinding: Binding<Bool> {
        .init(
            get: { budgetToDelete != nil },
            set: { if !$0 { budgetToDelete = nil } }
        )
    }
}

// MARK: - Budget Calculations

private extension BudgetView {
    func transactionsForBudget(_ budget: BudgetModel) -> [TransactionModel] {
        transactions.filter { transaction in
            transaction.type == .expense &&
            transaction.category == budget.category &&
            transaction.date >= budget.currentPeriodStart &&
            transaction.date <= budget.currentPeriodEnd
        }
    }

    func spentAmount(for budget: BudgetModel) -> Double {
        transactionsForBudget(budget).reduce(0) { $0 + $1.amount }
    }

    func convertedSpentAmount(for budget: BudgetModel) -> Double {
        transactionsForBudget(budget).reduce(0) { $0 + convertToBase($1.amount, from: $1.currency) }
    }

    func budgetStatus(for budget: BudgetModel) -> BudgetStatus {
        let spent = spentAmount(for: budget)
        let ratio = spent / budget.effectiveBudget
        if ratio >= 1.0 { return .exceeded }
        if ratio >= budget.alertThreshold { return .warning }
        return .onTrack
    }
}

// MARK: - Actions

private extension BudgetView {
    func fetchExchangeRates() async {
        guard let baseCurrency = Currency(rawValue: preferredCurrency) else { return }
        do {
            exchangeRates = try await currencyService.fetchRatesFromAPI(base: baseCurrency)
        } catch {
            print("Failed to fetch rates: \(error)")
        }
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

    func deleteBudget() {
        if let budget = budgetToDelete {
            modelContext.delete(budget)
        }
        budgetToDelete = nil
    }
}

// MARK: - Currency Helper

private extension BudgetView {
    func convertToBase(_ amount: Double, from currencyCode: String) -> Double {
        guard let fromCurrency = Currency(rawValue: currencyCode),
              let rates = exchangeRates else { return amount }
        return currencyService.convert(amount: amount, from: fromCurrency, to: baseCurrency, rates: rates)
    }
}

// MARK: - Preview

#Preview {
    BudgetView()
}
