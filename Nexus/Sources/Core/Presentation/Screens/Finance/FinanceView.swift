import SwiftUI
import SwiftData

struct FinanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransactionModel.date, order: .reverse) private var transactions: [TransactionModel]
    @Query(filter: #Predicate<BudgetModel> { $0.isActive }) private var budgets: [BudgetModel]
    @AppStorage("currency") private var preferredCurrency = "USD"

    @State private var showAddTransaction = false
    @State private var selectedTransaction: TransactionModel?
    @State private var selectedPeriod: TimePeriod = .month
    @State private var rangeStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var rangeEndDate: Date = Date()
    @State private var showDateRangePicker = false
    @State private var showBudgets = false
    @State private var exchangeRates: ExchangeRates?

    private let currencyService: CurrencyService = DefaultCurrencyService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodSelector
                    HouseSummaryCard()
                    SubscriptionsSummaryCard()
                    budgetPreviewCard
                    CurrencyCalculatorCard()
                    summaryCard
                    transactionsList
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .background(Color.nexusBackground)
            .navigationTitle("Finance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddTransaction = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                TransactionEditorView(transaction: nil)
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionEditorView(transaction: transaction)
            }
            .sheet(isPresented: $showDateRangePicker) {
                DateRangePickerSheet(startDate: $rangeStartDate, endDate: $rangeEndDate)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showBudgets) {
                BudgetView()
            }
            .task { await fetchExchangeRates() }
            .onChange(of: preferredCurrency) {
                Task { await fetchExchangeRates() }
            }
        }
    }
}

// MARK: - Computed Properties

private extension FinanceView {
    var baseCurrency: Currency { Currency(rawValue: preferredCurrency) ?? .usd }

    var periodTransactions: [TransactionModel] {
        let calendar = Calendar.current
        let now = Date()
        return transactions.filter { transaction in
            switch selectedPeriod {
            case .day: return calendar.isDateInToday(transaction.date)
            case .week: return calendar.isDate(transaction.date, equalTo: now, toGranularity: .weekOfYear)
            case .month: return calendar.isDate(transaction.date, equalTo: now, toGranularity: .month)
            case .year: return calendar.isDate(transaction.date, equalTo: now, toGranularity: .year)
            case .range:
                let startOfDay = calendar.startOfDay(for: rangeStartDate)
                let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: rangeEndDate) ?? rangeEndDate
                return transaction.date >= startOfDay && transaction.date <= endOfDay
            }
        }
    }

    var hasMultipleCurrencies: Bool { Set(periodTransactions.map { $0.currency }).count > 1 }

    var totalIncome: Double {
        periodTransactions.filter { $0.type == .income }.reduce(0) { $0 + convertToBase($1.amount, from: $1.currency) }
    }

    var totalExpense: Double {
        periodTransactions.filter { $0.type == .expense }.reduce(0) { $0 + convertToBase($1.amount, from: $1.currency) }
    }

    var balance: Double { totalIncome - totalExpense }

    var currencyBreakdown: [(currency: Currency, income: Double, expense: Double)] {
        var breakdown: [String: (income: Double, expense: Double)] = [:]
        for transaction in periodTransactions {
            let current = breakdown[transaction.currency] ?? (income: 0, expense: 0)
            if transaction.type == .income {
                breakdown[transaction.currency] = (current.income + transaction.amount, current.expense)
            } else if transaction.type == .expense {
                breakdown[transaction.currency] = (current.income, current.expense + transaction.amount)
            }
        }
        return breakdown.compactMap { key, value in
            guard let currency = Currency(rawValue: key) else { return nil }
            return (currency, value.income, value.expense)
        }.sorted { $0.currency.rawValue < $1.currency.rawValue }
    }

    var currentPeriodDates: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        switch selectedPeriod {
        case .day:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            return (start, end)
        case .week:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? now
            return (start, end)
        case .month:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? now
            return (start, end)
        case .year:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            let end = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start) ?? now
            return (start, end)
        case .range:
            return (rangeStartDate, rangeEndDate)
        }
    }
}

// MARK: - Period Selector

private extension FinanceView {
    var periodSelector: some View {
        VStack(spacing: 12) {
            periodButtons
            dateRangeDisplay
        }
    }

    var periodButtons: some View {
        GeometryReader { geometry in
            let tabWidth = geometry.size.width / CGFloat(TimePeriod.allCases.count)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.nexusGreen)
                    .frame(width: tabWidth - 4, height: geometry.size.height - 8)
                    .offset(x: CGFloat(TimePeriod.allCases.firstIndex(of: selectedPeriod) ?? 0) * tabWidth + 2)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedPeriod)

                HStack(spacing: 0) {
                    ForEach(TimePeriod.allCases) { period in
                        Text(period.title)
                            .font(.nexusCaption)
                            .fontWeight(selectedPeriod == period ? .semibold : .regular)
                            .foregroundStyle(selectedPeriod == period ? .white : .secondary)
                            .frame(width: tabWidth, height: geometry.size.height)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    selectedPeriod = period
                                }
                                if period == .range { showDateRangePicker = true }
                            }
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let index = Int(value.location.x / tabWidth)
                        let clampedIndex = max(0, min(index, TimePeriod.allCases.count - 1))
                        let newPeriod = TimePeriod.allCases[clampedIndex]
                        if newPeriod != selectedPeriod {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                selectedPeriod = newPeriod
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                    .onEnded { value in
                        let index = Int(value.location.x / tabWidth)
                        let clampedIndex = max(0, min(index, TimePeriod.allCases.count - 1))
                        if TimePeriod.allCases[clampedIndex] == .range { showDateRangePicker = true }
                    }
            )
        }
        .frame(height: 36)
        .padding(4)
        .background { Capsule().fill(Color.nexusSurface) }
    }

    var dateRangeDisplay: some View {
        let dates = currentPeriodDates
        return Group {
            if selectedPeriod == .range {
                Button { showDateRangePicker = true } label: {
                    dateRangeBadge(start: dates.start, end: dates.end, showChevron: true)
                }
                .buttonStyle(.plain)
            } else {
                dateRangeBadge(start: dates.start, end: dates.end, showChevron: false)
            }
        }
    }

    func dateRangeBadge(start: Date, end: Date, showChevron: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar").foregroundStyle(Color.nexusGreen)
            Text(formatDateRange(start: start, end: end)).font(.nexusSubheadline)
            if showChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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

// MARK: - Budget Preview Card

private extension FinanceView {
    var budgetPreviewCard: some View {
        Button { showBudgets = true } label: {
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.pie.fill").foregroundStyle(Color.nexusPurple)
                        Text("Budgets").font(.nexusHeadline)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("View All").font(.nexusCaption).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                if budgets.isEmpty { emptyBudgetState } else { budgetProgressList }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
                    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.nexusBorder, lineWidth: 1) }
            }
        }
        .buttonStyle(.plain)
    }

    var emptyBudgetState: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill").font(.system(size: 24)).foregroundStyle(Color.nexusPurple)
            VStack(alignment: .leading, spacing: 2) {
                Text("No Budgets Yet").font(.nexusSubheadline)
                Text("Tap to create your first budget").font(.nexusCaption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    var budgetProgressList: some View {
        VStack(spacing: 10) {
            ForEach(budgets.prefix(3)) { budget in budgetProgressRow(budget) }
            if budgets.count > 3 {
                Text("+\(budgets.count - 3) more").font(.nexusCaption).foregroundStyle(.secondary)
            }
        }
    }

    func budgetProgressRow(_ budget: BudgetModel) -> some View {
        let spent = currentPeriodSpent(for: budget)
        let progress = budget.effectiveBudget > 0 ? spent / budget.effectiveBudget : 0
        let color = TransactionCategoryColorMapper.color(for: budget.category.color)

        return HStack(spacing: 12) {
            Image(systemName: budget.category.icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background { Circle().fill(color.opacity(0.15)) }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(budget.name).font(.nexusSubheadline).lineLimit(1)
                    Spacer()
                    Text(formatBudgetCurrency(spent, currency: budget.currency))
                        .font(.nexusCaption)
                        .foregroundStyle(progress > 1 ? Color.nexusRed : .secondary)
                    Text("/").font(.nexusCaption).foregroundStyle(.tertiary)
                    Text(formatBudgetCurrency(budget.effectiveBudget, currency: budget.currency))
                        .font(.nexusCaption).foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.nexusBorder)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(progressColor(for: progress))
                            .frame(width: geometry.size.width * min(progress, 1.0))
                    }
                }
                .frame(height: 6)
            }
        }
    }

    func currentPeriodSpent(for budget: BudgetModel) -> Double {
        transactions
            .filter { $0.type == .expense && $0.category == budget.category }
            .filter { $0.date >= budget.currentPeriodStart && $0.date <= budget.currentPeriodEnd }
            .reduce(0) { $0 + $1.amount }
    }

    func progressColor(for progress: Double) -> Color {
        if progress >= 1.0 { return .nexusRed }
        if progress >= 0.8 { return .nexusOrange }
        return .nexusGreen
    }

    func formatBudgetCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Summary Card

private extension FinanceView {
    var summaryCard: some View {
        VStack(spacing: 16) {
            balanceHeader
            incomeExpenseRow
            if hasMultipleCurrencies { currencyBreakdownSection }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.nexusBorder, lineWidth: 1) }
        }
    }

    var balanceHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("Balance").font(.nexusSubheadline).foregroundStyle(.secondary)
                if hasMultipleCurrencies {
                    Text("(\(baseCurrency.rawValue))").font(.nexusCaption).foregroundStyle(.tertiary)
                }
            }
            Text(formatCurrency(balance))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(balance >= 0 ? Color.nexusGreen : Color.nexusRed)
        }
    }

    var incomeExpenseRow: some View {
        HStack(spacing: 24) {
            summaryItem(icon: "arrow.down.circle.fill", label: "Income", amount: totalIncome, color: .nexusGreen)
            Divider().frame(height: 40)
            summaryItem(icon: "arrow.up.circle.fill", label: "Expenses", amount: totalExpense, color: .nexusRed)
        }
    }

    func summaryItem(icon: String, label: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundStyle(color)
                Text(label).foregroundStyle(.secondary)
            }
            .font(.nexusCaption)
            Text(formatCurrency(amount)).font(.nexusHeadline).foregroundStyle(color)
        }
    }

    var currencyBreakdownSection: some View {
        VStack(spacing: 12) {
            Divider().background(Color.nexusBorder)
            VStack(alignment: .leading, spacing: 8) {
                Text("By Currency").font(.nexusCaption).foregroundStyle(.secondary)
                ForEach(currencyBreakdown, id: \.currency) { item in
                    let currencyBalance = item.income - item.expense
                    HStack {
                        HStack(spacing: 6) {
                            Text(item.currency.flag).font(.system(size: 16))
                            Text(item.currency.rawValue).font(.nexusSubheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.currency.format(currencyBalance))
                            .font(.nexusSubheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(currencyBalance >= 0 ? Color.nexusGreen : Color.nexusRed)
                    }
                }
            }
        }
    }
}

// MARK: - Transactions List

private extension FinanceView {
    var transactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transactions").font(.nexusHeadline).foregroundStyle(.secondary)
            if periodTransactions.isEmpty {
                emptyTransactionsState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(periodTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .onTapGesture { selectedTransaction = transaction }
                    }
                }
            }
        }
    }

    var emptyTransactionsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("No Transactions").font(.nexusHeadline)
            Text("Tap + to add your first transaction").font(.nexusSubheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Helper Methods

private extension FinanceView {
    func convertToBase(_ amount: Double, from currencyCode: String) -> Double {
        guard let fromCurrency = Currency(rawValue: currencyCode), let rates = exchangeRates else { return amount }
        return currencyService.convert(amount: amount, from: fromCurrency, to: baseCurrency, rates: rates)
    }

    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = preferredCurrency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(baseCurrency.symbol)0.00"
    }

    func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDate(start, inSameDayAs: end) {
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: start)
        }
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    func fetchExchangeRates() async {
        if let cached = CurrencyCache.getCachedRates(base: baseCurrency, context: modelContext), !cached.isStale {
            exchangeRates = cached
            return
        }
        do {
            let rates = try await currencyService.fetchRatesFromAPI(base: baseCurrency)
            exchangeRates = rates
            CurrencyCache.saveCachedRates(rates, context: modelContext)
        } catch {
            if let cached = CurrencyCache.getCachedRates(base: baseCurrency, context: modelContext) {
                exchangeRates = cached
            }
        }
    }
}

#Preview {
    FinanceView()
        .preferredColorScheme(.dark)
}
