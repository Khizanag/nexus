import SwiftUI
import SwiftData
import Charts

struct StockDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let symbol: String
    let name: String
    var holding: StockHoldingModel?
    var watchlistItem: WatchlistItemModel?

    @State private var quote: StockQuote?
    @State private var historicalData: [StockDataPoint] = []
    @State private var selectedRange: HistoricalRange = .month
    @State private var isLoading = true
    @State private var showAddTransaction = false
    @State private var showAddAlert = false
    @State private var showDeleteConfirmation = false

    private let stockService: StockService = FinnhubStockService()

    private var isInPortfolio: Bool { holding != nil }
    private var isInWatchlist: Bool { watchlistItem != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    priceHeader
                    chartSection
                    if isInPortfolio, let holding = holding {
                        holdingDetails(holding)
                    }
                    statsSection
                    actionsSection
                }
                .padding(20)
            }
            .background(Color.nexusBackground)
            .navigationTitle(symbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadData()
            }
            .onChange(of: selectedRange) {
                Task { await loadHistoricalData() }
            }
            .sheet(isPresented: $showAddTransaction) {
                if let holding = holding {
                    AddTransactionSheet(holding: holding)
                }
            }
            .sheet(isPresented: $showAddAlert) {
                AddAlertSheet(symbol: symbol, name: name, currentPrice: quote?.price ?? 0)
            }
            .confirmationDialog("Remove from \(isInPortfolio ? "Portfolio" : "Watchlist")?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    removeItem()
                }
            }
        }
    }

    // MARK: - Price Header

    private var priceHeader: some View {
        VStack(spacing: 8) {
            Text(name)
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)

            if let quote = quote {
                Text(quote.formattedPrice)
                    .font(.system(size: 42, weight: .bold, design: .rounded))

                HStack(spacing: 8) {
                    Image(systemName: quote.isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 14, weight: .bold))

                    Text(quote.formattedChange)
                    Text("(\(quote.formattedChangePercent))")
                }
                .font(.nexusHeadline)
                .foregroundStyle(quote.isUp ? Color.nexusGreen : Color.nexusRed)

                Text("As of \(quote.timestamp.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(spacing: 16) {
            if historicalData.isEmpty {
                chartPlaceholder
            } else {
                stockChart
            }

            rangeSelector
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
        }
    }

    private var stockChart: some View {
        let minPrice = historicalData.map { $0.close }.min() ?? 0
        let maxPrice = historicalData.map { $0.close }.max() ?? 100
        let priceRange = maxPrice - minPrice
        let padding = priceRange * 0.1

        return Chart(historicalData) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Price", point.close)
            )
            .foregroundStyle(chartColor)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", point.date),
                y: .value("Price", point.close)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [chartColor.opacity(0.3), chartColor.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: (minPrice - padding)...(maxPrice + padding))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel(format: xAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text("$\(price, specifier: "%.0f")")
                            .font(.system(size: 10))
                    }
                }
            }
        }
        .frame(height: 200)
    }

    private var chartPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusBorder.opacity(0.3))

            if isLoading {
                ProgressView()
            } else {
                Text("No data available")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 200)
    }

    private var chartColor: Color {
        guard let first = historicalData.first?.close,
              let last = historicalData.last?.close else {
            return .gray
        }
        return last >= first ? Color.nexusGreen : Color.nexusRed
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .day: .dateTime.hour()
        case .week: .dateTime.weekday(.abbreviated)
        case .month, .threeMonths: .dateTime.month(.abbreviated).day()
        case .year, .fiveYears: .dateTime.month(.abbreviated)
        }
    }

    private var rangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(HistoricalRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.displayName)
                        .font(.system(size: 13, weight: selectedRange == range ? .semibold : .regular))
                        .foregroundStyle(selectedRange == range ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedRange == range {
                                Capsule()
                                    .fill(Color.nexusPurple)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(Color.nexusBackground)
        }
    }

    // MARK: - Holding Details

    private func holdingDetails(_ holding: StockHoldingModel) -> some View {
        let currentPrice = quote?.price ?? holding.averageCostPerShare
        let gainLoss = holding.gainLoss(at: currentPrice)
        let gainLossPercent = holding.gainLossPercent(at: currentPrice)

        return VStack(spacing: 16) {
            HStack {
                Text("Your Position")
                    .font(.nexusHeadline)
                Spacer()
                Button("Add Transaction") {
                    showAddTransaction = true
                }
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusPurple)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shares")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    Text(formatQuantity(holding.quantity))
                        .font(.nexusHeadline)
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Text("Avg Cost")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(holding.averageCostPerShare))
                        .font(.nexusHeadline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Value")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(holding.currentValue(at: currentPrice)))
                        .font(.nexusHeadline)
                }
            }

            Divider().background(Color.nexusBorder)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Gain/Loss")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(formatCurrency(gainLoss, showSign: true))
                        Text("(\(formatPercent(gainLossPercent)))")
                    }
                    .font(.nexusHeadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(gainLoss >= 0 ? Color.nexusGreen : Color.nexusRed)
                }

                Spacer()
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.nexusHeadline)

            if let quote = quote {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(label: "Open", value: formatCurrency(quote.open))
                    StatCard(label: "Previous Close", value: formatCurrency(quote.previousClose))
                    StatCard(label: "Day High", value: formatCurrency(quote.high))
                    StatCard(label: "Day Low", value: formatCurrency(quote.low))
                    if let pe = quote.peRatio {
                        StatCard(label: "P/E Ratio", value: String(format: "%.2f", pe))
                    }
                    if let dividend = quote.dividend, dividend > 0 {
                        StatCard(label: "Dividend Yield", value: String(format: "%.2f%%", dividend))
                    }
                    if let marketCap = quote.marketCap {
                        StatCard(label: "Market Cap", value: formatMarketCap(marketCap))
                    }
                    StatCard(label: "Volume", value: formatVolume(quote.volume))
                }
            } else {
                Text("Loading...")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showAddAlert = true
            } label: {
                HStack {
                    Image(systemName: "bell.fill")
                    Text("Set Price Alert")
                }
                .font(.nexusSubheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.nexusOrange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.nexusOrange.opacity(0.15))
                }
            }

            if !isInWatchlist, !isInPortfolio {
                HStack(spacing: 12) {
                    Button {
                        addToWatchlist()
                    } label: {
                        HStack {
                            Image(systemName: "eye.fill")
                            Text("Watch")
                        }
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.nexusPurple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.nexusPurple.opacity(0.15))
                        }
                    }

                    Button {
                        // Add to portfolio - would open AddStockSheet
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Buy")
                        }
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.nexusGreen)
                        }
                    }
                }
            }

            if isInPortfolio || isInWatchlist {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Remove from \(isInPortfolio ? "Portfolio" : "Watchlist")")
                    }
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadData() async {
        isLoading = true
        async let quoteTask = stockService.getQuote(symbol: symbol)
        async let historyTask = stockService.getHistoricalData(symbol: symbol, range: selectedRange)

        do {
            quote = try await quoteTask
            historicalData = try await historyTask
        } catch {
            print("Error loading data: \(error)")
        }

        isLoading = false
    }

    private func loadHistoricalData() async {
        do {
            historicalData = try await stockService.getHistoricalData(symbol: symbol, range: selectedRange)
        } catch {
            print("Error loading historical data: \(error)")
        }
    }

    private func addToWatchlist() {
        let item = WatchlistItemModel(symbol: symbol, name: name)
        modelContext.insert(item)
        try? modelContext.save()
    }

    private func removeItem() {
        if let holding = holding {
            modelContext.delete(holding)
        }
        if let watchlistItem = watchlistItem {
            modelContext.delete(watchlistItem)
        }
        try? modelContext.save()
        dismiss()
    }

    private func formatQuantity(_ qty: Double) -> String {
        if qty.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", qty)
        }
        return String(format: "%.4f", qty)
    }

    private func formatCurrency(_ amount: Double, showSign: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        if showSign, amount > 0 {
            return "+\(formatter.string(from: NSNumber(value: amount)) ?? "$0.00")"
        }
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    private func formatPercent(_ percent: Double) -> String {
        let sign = percent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, percent)
    }

    private func formatMarketCap(_ cap: Double) -> String {
        if cap >= 1_000_000_000_000 {
            return String(format: "$%.2fT", cap / 1_000_000_000_000)
        } else if cap >= 1_000_000_000 {
            return String(format: "$%.2fB", cap / 1_000_000_000)
        } else if cap >= 1_000_000 {
            return String(format: "$%.2fM", cap / 1_000_000)
        }
        return String(format: "$%.0f", cap)
    }

    private func formatVolume(_ volume: Int) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.2fM", Double(volume) / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.1fK", Double(volume) / 1_000)
        }
        return "\(volume)"
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.nexusSubheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.nexusBackground)
        }
    }
}

// MARK: - Add Transaction Sheet

struct AddTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var holding: StockHoldingModel

    @State private var transactionType = StockTransactionType.buy
    @State private var quantity = ""
    @State private var pricePerShare = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $transactionType) {
                    Text("Buy").tag(StockTransactionType.buy)
                    Text("Sell").tag(StockTransactionType.sell)
                }
                .pickerStyle(.segmented)

                Section {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)

                    TextField("Price per Share", text: $pricePerShare)
                        .keyboardType(.decimalPad)
                }

                if transactionType == .sell {
                    Section {
                        Text("Available: \(String(format: "%.4f", holding.quantity)) shares")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Record Transaction") {
                        recordTransaction()
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var isValid: Bool {
        guard let qty = Double(quantity), let price = Double(pricePerShare),
              qty > 0, price > 0 else { return false }
        if transactionType == .sell, qty > holding.quantity { return false }
        return true
    }

    private func recordTransaction() {
        guard let qty = Double(quantity), let price = Double(pricePerShare) else { return }

        if transactionType == .buy {
            holding.addShares(quantity: qty, price: price)
        } else {
            _ = holding.removeShares(quantity: qty, price: price)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Add Alert Sheet

struct AddAlertSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let symbol: String
    let name: String
    let currentPrice: Double

    @State private var alertType = StockAlertType.priceAbove
    @State private var targetPrice = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(symbol)
                            .font(.nexusHeadline)
                        Spacer()
                        Text("Current: $\(String(format: "%.2f", currentPrice))")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Alert Type") {
                    Picker("Type", selection: $alertType) {
                        Text("Price Above").tag(StockAlertType.priceAbove)
                        Text("Price Below").tag(StockAlertType.priceBelow)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Target Price") {
                    TextField("$0.00", text: $targetPrice)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button("Create Alert") {
                        createAlert()
                    }
                    .disabled(Double(targetPrice) == nil)
                }
            }
            .navigationTitle("Set Price Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if currentPrice > 0 {
                    let suggested = alertType == .priceAbove ? currentPrice * 1.05 : currentPrice * 0.95
                    targetPrice = String(format: "%.2f", suggested)
                }
            }
            .onChange(of: alertType) {
                if currentPrice > 0 {
                    let suggested = alertType == .priceAbove ? currentPrice * 1.05 : currentPrice * 0.95
                    targetPrice = String(format: "%.2f", suggested)
                }
            }
        }
    }

    private func createAlert() {
        guard let price = Double(targetPrice) else { return }

        let alert = StockAlertModel(
            symbol: symbol,
            name: name,
            alertType: alertType,
            targetPrice: price
        )
        modelContext.insert(alert)
        try? modelContext.save()
        dismiss()
    }
}
