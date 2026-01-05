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

    private var baseCurrency: Currency {
        Currency(rawValue: preferredCurrency) ?? .usd
    }

    private var periodTransactions: [TransactionModel] {
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

    private var usedCurrencies: Set<String> {
        Set(periodTransactions.map { $0.currency })
    }

    private var hasMultipleCurrencies: Bool {
        usedCurrencies.count > 1
    }

    private func convertToBase(_ amount: Double, from currencyCode: String) -> Double {
        guard let fromCurrency = Currency(rawValue: currencyCode),
              let rates = exchangeRates else {
            return amount
        }
        return currencyService.convert(amount: amount, from: fromCurrency, to: baseCurrency, rates: rates)
    }

    private var totalIncome: Double {
        periodTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + convertToBase($1.amount, from: $1.currency) }
    }

    private var totalExpense: Double {
        periodTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + convertToBase($1.amount, from: $1.currency) }
    }

    private var balance: Double {
        totalIncome - totalExpense
    }

    private var currencyBreakdown: [(currency: Currency, income: Double, expense: Double)] {
        var breakdown: [String: (income: Double, expense: Double)] = [:]

        for transaction in periodTransactions {
            let current = breakdown[transaction.currency] ?? (income: 0, expense: 0)
            if transaction.type == .income {
                breakdown[transaction.currency] = (income: current.income + transaction.amount, expense: current.expense)
            } else if transaction.type == .expense {
                breakdown[transaction.currency] = (income: current.income, expense: current.expense + transaction.amount)
            }
        }

        return breakdown.compactMap { key, value in
            guard let currency = Currency(rawValue: key) else { return nil }
            return (currency: currency, income: value.income, expense: value.expense)
        }.sorted { $0.currency.rawValue < $1.currency.rawValue }
    }

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
                DateRangePickerSheet(
                    startDate: $rangeStartDate,
                    endDate: $rangeEndDate
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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

    private var periodSelector: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(TimePeriod.allCases) { period in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedPeriod = period
                            if period == .range {
                                showDateRangePicker = true
                            }
                        }
                    } label: {
                        Text(period.title)
                            .font(.nexusCaption)
                            .fontWeight(selectedPeriod == period ? .semibold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                if selectedPeriod == period {
                                    Capsule()
                                        .fill(Color.nexusGreen)
                                }
                            }
                            .foregroundStyle(selectedPeriod == period ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background {
                Capsule()
                    .fill(Color.nexusSurface)
            }

            if selectedPeriod == .range {
                dateRangeDisplay
            }
        }
    }

    private var dateRangeDisplay: some View {
        Button {
            showDateRangePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.nexusGreen)
                Text(formatDateRange())
                    .font(.nexusSubheadline)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
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
        .buttonStyle(.plain)
    }

    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: rangeStartDate)
        let end = formatter.string(from: rangeEndDate)
        return "\(start) - \(end)"
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
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

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(Color.nexusGreen)
                        Text("Income")
                            .foregroundStyle(.secondary)
                    }
                    .font(.nexusCaption)

                    Text(formatCurrency(totalIncome))
                        .font(.nexusHeadline)
                        .foregroundStyle(Color.nexusGreen)
                }

                Divider()
                    .frame(height: 40)

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(Color.nexusRed)
                        Text("Expenses")
                            .foregroundStyle(.secondary)
                    }
                    .font(.nexusCaption)

                    Text(formatCurrency(totalExpense))
                        .font(.nexusHeadline)
                        .foregroundStyle(Color.nexusRed)
                }
            }

            if hasMultipleCurrencies {
                currencyBreakdownView
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

    @ViewBuilder
    private var currencyBreakdownView: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.nexusBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("By Currency")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

                ForEach(currencyBreakdown, id: \.currency) { item in
                    HStack {
                        HStack(spacing: 6) {
                            Text(item.currency.flag)
                                .font(.system(size: 16))
                            Text(item.currency.rawValue)
                                .font(.nexusSubheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        let currencyBalance = item.income - item.expense
                        Text(item.currency.format(currencyBalance))
                            .font(.nexusSubheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(currencyBalance >= 0 ? Color.nexusGreen : Color.nexusRed)
                    }
                }
            }
        }
    }

    private var transactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transactions")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            if periodTransactions.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(periodTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .onTapGesture {
                                selectedTransaction = transaction
                            }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
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

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = preferredCurrency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Currency(rawValue: preferredCurrency)?.symbol ?? "$")0.00"
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
            Image(systemName: transaction.category.icon)
                .font(.system(size: 16))
                .foregroundStyle(categoryColor)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title)
                    .font(.nexusSubheadline)

                Text(transaction.category.rawValue.capitalized)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(.nexusHeadline)
                    .foregroundStyle(transaction.type == .income ? Color.nexusGreen : Color.primary)

                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
        }
    }

    private var categoryColor: Color {
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

    private var amountText: String {
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
                VStack(alignment: .leading, spacing: 12) {
                    Text("Start Date")
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        "",
                        selection: $startDate,
                        in: ...endDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Color.nexusGreen)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("End Date")
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        "",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .tint(Color.nexusGreen)
                }

                Spacer()
            }
            .padding(20)
            .background(Color.nexusBackground)
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    FinanceView()
        .preferredColorScheme(.dark)
}
