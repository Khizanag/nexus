import SwiftUI
import SwiftData

struct FinanceView: View {
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

    private let currencyService: CurrencyServiceProtocol = CurrencyService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodSelector
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
                    Button {
                        showAddTransaction = true
                    } label: {
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
            .task { await fetchExchangeRates() }
            .onChange(of: preferredCurrency) {
                Task { await fetchExchangeRates() }
            }
        }
    }
}

// MARK: - Computed Properties

private extension FinanceView {
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

    var balance: Double {
        totalIncome - totalExpense
    }

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
        HStack(spacing: 6) {
            ForEach(TimePeriod.allCases) { period in
                periodButton(for: period)
            }
        }
        .padding(4)
        .background { Capsule().fill(Color.nexusSurface) }
    }

    func periodButton(for period: TimePeriod) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedPeriod = period
                if period == .range { showDateRangePicker = true }
            }
        } label: {
            Text(period.title)
                .font(.nexusCaption)
                .fontWeight(selectedPeriod == period ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if selectedPeriod == period {
                        Capsule().fill(Color.nexusGreen)
                    }
                }
                .foregroundStyle(selectedPeriod == period ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    var dateRangeDisplay: some View {
        let dates = currentPeriodDates
        let isCustomRange = selectedPeriod == .range

        return Group {
            if isCustomRange {
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
            Image(systemName: "calendar")
                .foregroundStyle(Color.nexusGreen)
            Text(formatDateRange(start: start, end: end))
                .font(.nexusSubheadline)
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

// MARK: - Summary Card

private extension FinanceView {
    var summaryCard: some View {
        VStack(spacing: 16) {
            balanceHeader
            incomeExpenseRow
            if hasMultipleCurrencies {
                currencyBreakdownSection
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }

    var balanceHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("Balance")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
                if hasMultipleCurrencies {
                    Text("(\(baseCurrency.rawValue))")
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(formatCurrency(balance))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(balance >= 0 ? Color.nexusGreen : Color.nexusRed)
        }
    }

    var incomeExpenseRow: some View {
        HStack(spacing: 24) {
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

            Text(formatCurrency(amount))
                .font(.nexusHeadline)
                .foregroundStyle(color)
        }
    }

    var currencyBreakdownSection: some View {
        VStack(spacing: 12) {
            Divider().background(Color.nexusBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("By Currency")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

                ForEach(currencyBreakdown, id: \.currency) { item in
                    currencyBreakdownRow(item: item)
                }
            }
        }
    }

    func currencyBreakdownRow(item: (currency: Currency, income: Double, expense: Double)) -> some View {
        let currencyBalance = item.income - item.expense
        return HStack {
            HStack(spacing: 6) {
                Text(item.currency.flag)
                    .font(.system(size: 16))
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

// MARK: - Transactions List

private extension FinanceView {
    var transactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transactions")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

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
            Image(systemName: "creditcard")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Transactions")
                .font(.nexusHeadline)
            Text("Tap + to add your first transaction")
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Helper Methods

private extension FinanceView {
    func convertToBase(_ amount: Double, from currencyCode: String) -> Double {
        guard let fromCurrency = Currency(rawValue: currencyCode),
              let rates = exchangeRates else { return amount }
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
            } else {
                print("Currency fetch error: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
            }
        }
    }
}

// MARK: - Time Period

private enum TimePeriod: String, CaseIterable, Identifiable {
    case day, week, month, year, range

    var id: String { rawValue }

    var title: String {
        switch self {
        case .range: "Range"
        default: rawValue.capitalized
        }
    }
}

// MARK: - Transaction Row

private struct TransactionRow: View {
    let transaction: TransactionModel

    var body: some View {
        HStack(spacing: 12) {
            categoryIcon
            titleAndCategory
            Spacer()
            amountAndDate
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
        }
    }

    var categoryIcon: some View {
        Image(systemName: transaction.category.icon)
            .font(.system(size: 16))
            .foregroundStyle(categoryColor)
            .frame(width: 40, height: 40)
            .background {
                Circle().fill(categoryColor.opacity(0.15))
            }
    }

    var titleAndCategory: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(transaction.title)
                .font(.nexusSubheadline)
            Text(transaction.category.rawValue.capitalized)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
    }

    var amountAndDate: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formattedAmount)
                .font(.nexusHeadline)
                .foregroundStyle(transaction.type == .income ? Color.nexusGreen : Color.primary)
            Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
    }

    var categoryColor: Color {
        switch transaction.category.color {
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
        default: .secondary
        }
    }

    var formattedAmount: String {
        let prefix = transaction.type == .income ? "+" : "-"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        let amount = formatter.string(from: NSNumber(value: transaction.amount)) ?? "$0.00"
        return "\(prefix)\(amount)"
    }
}

// MARK: - Date Range Picker Sheet

private struct DateRangePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startDate: Date
    @Binding var endDate: Date

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                datePickersRow
                daysSelectedLabel
                quickSelectGrid
                Spacer()
            }
            .padding(20)
            .background(Color.nexusBackground)
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    var datePickersRow: some View {
        HStack {
            datePicker(label: "Start Date", selection: $startDate, range: ...endDate, alignment: .leading)
            Spacer()
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            Spacer()
            datePicker(label: "End Date", selection: $endDate, range: startDate..., alignment: .trailing)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12).fill(Color.nexusSurface)
        }
    }

    func datePicker(label: String, selection: Binding<Date>, range: PartialRangeThrough<Date>, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(label)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
            DatePicker("", selection: selection, in: range, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.nexusGreen)
        }
    }

    func datePicker(label: String, selection: Binding<Date>, range: PartialRangeFrom<Date>, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(label)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
            DatePicker("", selection: selection, in: range, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.nexusGreen)
        }
    }

    var daysSelectedLabel: some View {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return Text("Selected: \(days + 1) days")
            .font(.nexusCaption)
            .foregroundStyle(.secondary)
    }

    var quickSelectGrid: some View {
        VStack(spacing: 12) {
            Text("Quick Select")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickSelectButton("Last 7 Days", days: 7)
                quickSelectButton("Last 14 Days", days: 14)
                quickSelectButton("Last 30 Days", days: 30)
                quickSelectButton("Last 90 Days", days: 90)
            }
        }
    }

    func quickSelectButton(_ title: String, days: Int) -> some View {
        Button {
            endDate = Date()
            startDate = Calendar.current.date(byAdding: .day, value: -(days - 1), to: endDate) ?? endDate
        } label: {
            Text(title)
                .font(.nexusSubheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 10).fill(Color.nexusSurfaceSecondary)
                }
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FinanceView()
        .preferredColorScheme(.dark)
}
