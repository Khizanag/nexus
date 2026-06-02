import SwiftUI
import SwiftData
import Charts

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransactionModel.date, order: .reverse) private var transactions: [TransactionModel]
    @AppStorage("currency") private var preferredCurrency = "USD"

    @State private var showAddTransaction = false
    @State private var selectedTransaction: TransactionModel?
    @State private var selectedPeriod: TimePeriod = .month
    @State private var rangeStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var rangeEndDate: Date = Date()
    @State private var showDateRangePicker = false
    @State private var exchangeRates: ExchangeRates?
    @State private var searchText = ""

    private let currencyService: CurrencyService = DefaultCurrencyService()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            mainContent
                .background(Color.nexusBackground)
                .navigationTitle("Transactions")
                .searchable(text: $searchText, prompt: "Search transactions")
                .toolbar { toolbarContent }
                .sheet(isPresented: $showAddTransaction) { TransactionEditorView(transaction: nil) }
                .sheet(item: $selectedTransaction) { TransactionEditorView(transaction: $0) }
                .sheet(isPresented: $showDateRangePicker) {
                    DateRangePickerSheet(startDate: $rangeStartDate, endDate: $rangeEndDate)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
                .task { await fetchExchangeRates() }
                .onChange(of: preferredCurrency) { _, _ in Task { await fetchExchangeRates() } }
        }
    }
}

// MARK: - Toolbar

private extension TransactionsView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAddTransaction = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add transaction")
        }
    }
}

// MARK: - Main Content

private extension TransactionsView {
    var mainContent: some View {
        List {
            periodSelectorSection
            summarySection
            chartSection
            transactionsSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

// MARK: - Period Selector Section

private extension TransactionsView {
    var periodSelectorSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases.filter { $0 != .range }) { period in
                        Text(period.title).tag(period)
                    }
                    Text("Range").tag(TimePeriod.range)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedPeriod) { _, new in
                    if new == .range { showDateRangePicker = true }
                }

                if selectedPeriod == .range {
                    Button {
                        showDateRangePicker = true
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "calendar")
                                .foregroundStyle(Color.nexusGreen)
                            Text(formatDateRange(start: rangeStartDate, end: rangeEndDate))
                                .font(.nexusSubheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: DesignSystem.Size.Icon.sm, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Change date range")
                    .accessibilityValue(formatDateRange(start: rangeStartDate, end: rangeEndDate))
                } else {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.nexusGreen)
                        Text(formatDateRange(start: currentPeriodDates.start, end: currentPeriodDates.end))
                            .font(.nexusSubheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .listRowBackground(Color.nexusSurface)
        }
        .listSectionSeparator(.hidden)
    }
}

// MARK: - Summary Section

private extension TransactionsView {
    var summarySection: some View {
        Section {
            VStack(spacing: DesignSystem.Spacing.md) {
                balanceRow
                Divider()
                incomeExpenseRow
                if hasMultipleCurrencies {
                    Divider()
                    currencyBreakdownContent
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .listRowBackground(Color.nexusSurface)
        }
        .listSectionSeparator(.hidden)
    }

    var balanceRow: some View {
        VStack(spacing: 4) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Text("Balance")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
                if hasMultipleCurrencies {
                    Text("(\(baseCurrency.rawValue))")
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(balance.formatted(.currency(code: preferredCurrency)))
                .font(.nexusDisplayNumber(.title))
                .foregroundStyle(balance >= 0 ? Color.nexusGreen : Color.nexusRed)
                .accessibilityLabel("Balance: \(balance.formatted(.currency(code: preferredCurrency)))")
        }
        .frame(maxWidth: .infinity)
    }

    var incomeExpenseRow: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            summaryItem(
                icon: "arrow.down.circle.fill",
                label: "Income",
                amount: totalIncome,
                color: .nexusGreen
            )
            Divider().frame(height: 40)
            summaryItem(
                icon: "arrow.up.circle.fill",
                label: "Expenses",
                amount: totalExpense,
                color: .nexusRed
            )
        }
        .frame(maxWidth: .infinity)
    }

    func summaryItem(icon: String, label: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(label)
                    .foregroundStyle(.secondary)
            }
            .font(.nexusCaption)
            Text(amount.formatted(.currency(code: preferredCurrency)))
                .font(.nexusHeadline)
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(amount.formatted(.currency(code: preferredCurrency)))")
    }

    var currencyBreakdownContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("By Currency")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)

            ForEach(currencyBreakdown, id: \.currency) { item in
                let currencyBalance = item.income - item.expense
                HStack {
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        Text(item.currency.flag)
                        Text(item.currency.rawValue)
                            .font(.nexusSubheadline)
                            .foregroundStyle(.secondary)
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

// MARK: - Chart Section

private extension TransactionsView {
    var chartSection: some View {
        Section {
            if periodTransactions.isEmpty {
                EmptyView()
            } else {
                categoryChart
                    .listRowBackground(Color.nexusSurface)
            }
        }
        .listSectionSeparator(.hidden)
    }

    var categoryChart: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Breakdown")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            Chart(categoryChartData, id: \.category) { item in
                BarMark(
                    x: .value("Amount", item.amount),
                    y: .value("Category", item.label)
                )
                .foregroundStyle(item.color.gradient)
                .cornerRadius(DesignSystem.CornerRadius.sm)
                .annotation(position: .trailing) {
                    Text(item.amount.formatted(.currency(code: preferredCurrency)))
                        .font(.nexusCaption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(categoryChartData.count) * 36)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    struct ChartItem {
        let category: String
        let label: String
        let amount: Double
        let color: Color
    }

    var categoryChartData: [ChartItem] {
        let expensesByCategory = periodTransactions
            .filter { $0.type == .expense }
            .reduce(into: [TransactionCategory: Double]()) { acc, t in
                acc[t.category, default: 0] += convertToBase(t.amount, from: t.currency)
            }

        return expensesByCategory
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { category, amount in
                ChartItem(
                    category: category.rawValue,
                    label: category.rawValue.capitalized,
                    amount: amount,
                    color: TransactionCategoryColorMapper.color(for: category.color)
                )
            }
    }
}

// MARK: - Transactions Section

private extension TransactionsView {
    var transactionsSection: some View {
        let grouped = groupedTransactions

        return Group {
            if isSearching && filteredTransactions.isEmpty {
                Section {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                }
                .listSectionSeparator(.hidden)
            } else if !isSearching && periodTransactions.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "creditcard",
                        description: Text("Tap + to add your first transaction")
                    )
                    .listRowBackground(Color.clear)
                }
                .listSectionSeparator(.hidden)
            } else {
                ForEach(grouped, id: \.date) { group in
                    Section(header: Text(group.date.formatted(date: .complete, time: .omitted))
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    ) {
                        ForEach(group.transactions) { transaction in
                            TransactionRow(transaction: transaction)
                                .listRowBackground(Color.nexusSurface)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .onTapGesture { selectedTransaction = transaction }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        modelContext.delete(transaction)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        selectedTransaction = transaction
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(Color.nexusBlue)
                                }
                        }
                    }
                }
            }
        }
    }

    var isSearching: Bool {
        !searchText.isEmpty
    }

    var filteredTransactions: [TransactionModel] {
        let query = searchText.lowercased()
        return periodTransactions.filter { transaction in
            transaction.title.lowercased().contains(query)
                || transaction.category.rawValue.lowercased().contains(query)
                || transaction.notes.lowercased().contains(query)
        }
    }

    var displayedTransactions: [TransactionModel] {
        isSearching ? filteredTransactions : periodTransactions
    }

    struct TransactionGroup {
        let date: Date
        let transactions: [TransactionModel]
    }

    var groupedTransactions: [TransactionGroup] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: displayedTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return dict
            .sorted { $0.key > $1.key }
            .map { TransactionGroup(date: $0.key, transactions: $0.value) }
    }
}

// MARK: - Computed Properties

private extension TransactionsView {
    var baseCurrency: Currency {
        Currency(rawValue: preferredCurrency) ?? .usd
    }

    var periodTransactions: [TransactionModel] {
        let calendar = Calendar.current
        let now = Date()
        return transactions.filter { transaction in
            switch selectedPeriod {
            case .day:
                return calendar.isDateInToday(transaction.date)
            case .week:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .year)
            case .range:
                let startOfDay = calendar.startOfDay(for: rangeStartDate)
                let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: rangeEndDate) ?? rangeEndDate
                return transaction.date >= startOfDay && transaction.date <= endOfDay
            }
        }
    }

    var hasMultipleCurrencies: Bool {
        Set(periodTransactions.map { $0.currency }).count > 1
    }

    var totalIncome: Double {
        periodTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + convertToBase($1.amount, from: $1.currency) }
    }

    var totalExpense: Double {
        periodTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + convertToBase($1.amount, from: $1.currency) }
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

// MARK: - Helper Methods

private extension TransactionsView {
    func convertToBase(_ amount: Double, from currencyCode: String) -> Double {
        guard
            let fromCurrency = Currency(rawValue: currencyCode),
            let rates = exchangeRates
        else { return amount }
        return currencyService.convert(amount: amount, from: fromCurrency, to: baseCurrency, rates: rates)
    }

    func formatDateRange(start: Date, end: Date) -> String {
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return start.formatted(Date.FormatStyle().weekday(.wide).month(.abbreviated).day())
        }
        let s = start.formatted(Date.FormatStyle().month(.abbreviated).day())
        let e = end.formatted(Date.FormatStyle().month(.abbreviated).day())
        return "\(s) – \(e)"
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

// MARK: - Preview

#Preview {
    TransactionsView()
}
