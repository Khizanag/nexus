import SwiftUI
import SwiftData

struct StocksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StockHoldingModel.symbol) private var holdings: [StockHoldingModel]
    @Query(sort: \WatchlistItemModel.symbol) private var watchlist: [WatchlistItemModel]
    @Query(filter: #Predicate<StockAlertModel> { $0.isActive }) private var alerts: [StockAlertModel]

    @State private var selectedTab = 0
    @State private var quotes: [String: StockQuote] = [:]
    @State private var isLoading = false
    @State private var showAddSheet = false
    @State private var selectedHolding: StockHoldingModel?
    @State private var selectedWatchlistItem: WatchlistItemModel?
    @State private var showAlerts = false
    @State private var lastRefresh = Date()

    private let stockService: StockService = FinnhubStockService()

    private var allSymbols: [String] {
        let holdingSymbols = holdings.map { $0.symbol }
        let watchlistSymbols = watchlist.map { $0.symbol }
        return Array(Set(holdingSymbols + watchlistSymbols))
    }

    private var totalPortfolioValue: Double {
        holdings.reduce(0) { total, holding in
            let price = quotes[holding.symbol]?.price ?? holding.averageCostPerShare
            return total + holding.currentValue(at: price)
        }
    }

    private var totalCost: Double {
        holdings.reduce(0) { $0 + $1.totalCost }
    }

    private var totalGainLoss: Double {
        totalPortfolioValue - totalCost
    }

    private var totalGainLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (totalGainLoss / totalCost) * 100
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !holdings.isEmpty {
                    portfolioSummaryHeader
                }

                Picker("", selection: $selectedTab) {
                    Text("Portfolio (\(holdings.count))").tag(0)
                    Text("Watchlist (\(watchlist.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if isLoading && quotes.isEmpty {
                    loadingView
                } else {
                    TabView(selection: $selectedTab) {
                        portfolioTab.tag(0)
                        watchlistTab.tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .background(Color.nexusBackground)
            .navigationTitle("Stocks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        if !alerts.isEmpty {
                            Button {
                                showAlerts = true
                            } label: {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundStyle(Color.nexusOrange)
                            }
                        }
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
            .refreshable {
                await refreshQuotes()
            }
            .task {
                await refreshQuotes()
            }
            .sheet(isPresented: $showAddSheet) {
                AddStockSheet(mode: selectedTab == 0 ? .portfolio : .watchlist)
            }
            .sheet(item: $selectedHolding) { holding in
                StockDetailView(
                    symbol: holding.symbol,
                    name: holding.name,
                    holding: holding
                )
            }
            .sheet(item: $selectedWatchlistItem) { item in
                StockDetailView(
                    symbol: item.symbol,
                    name: item.name,
                    watchlistItem: item
                )
            }
            .sheet(isPresented: $showAlerts) {
                AlertsListView()
            }
        }
    }

    // MARK: - Portfolio Summary Header

    private var portfolioSummaryHeader: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Portfolio Value")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

                Text(formatCurrency(totalPortfolioValue))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
            }

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("Total Cost")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(formatCurrency(totalCost))
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)
                }

                Rectangle()
                    .fill(Color.nexusBorder)
                    .frame(width: 1, height: 30)

                VStack(spacing: 2) {
                    Text("Gain/Loss")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 4) {
                        Text(formatCurrency(totalGainLoss, showSign: true))
                        Text("(\(formatPercent(totalGainLossPercent)))")
                    }
                    .font(.nexusSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(totalGainLoss >= 0 ? Color.nexusGreen : Color.nexusRed)
                }
            }

            Text("Last updated: \(lastRefresh.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.nexusSurface)
    }

    // MARK: - Portfolio Tab

    private var portfolioTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if holdings.isEmpty {
                    emptyPortfolioState
                } else {
                    ForEach(holdings) { holding in
                        StockHoldingRow(
                            holding: holding,
                            quote: quotes[holding.symbol]
                        ) {
                            selectedHolding = holding
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Watchlist Tab

    private var watchlistTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if watchlist.isEmpty {
                    emptyWatchlistState
                } else {
                    ForEach(watchlist) { item in
                        WatchlistRow(
                            item: item,
                            quote: quotes[item.symbol]
                        ) {
                            selectedWatchlistItem = item
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Empty States

    private var emptyPortfolioState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Holdings Yet")
                .font(.nexusHeadline)

            Text("Add stocks to track your portfolio performance")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showAddSheet = true
            } label: {
                Label("Add Stock", systemImage: "plus")
                    .font(.nexusSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background { Capsule().fill(Color.nexusGreen) }
            }
        }
        .padding(40)
    }

    private var emptyWatchlistState: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Watchlist Empty")
                .font(.nexusHeadline)

            Text("Add stocks to watch their price movements")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showAddSheet = true
            } label: {
                Label("Add to Watchlist", systemImage: "plus")
                    .font(.nexusSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background { Capsule().fill(Color.nexusPurple) }
            }
        }
        .padding(40)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading quotes...")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func refreshQuotes() async {
        guard !allSymbols.isEmpty else { return }
        isLoading = true

        do {
            let fetchedQuotes = try await stockService.getQuotes(symbols: allSymbols)
            for quote in fetchedQuotes {
                quotes[quote.symbol] = quote
            }
            lastRefresh = Date()
        } catch {
            print("Failed to fetch quotes: \(error)")
        }

        isLoading = false
    }

    private func formatCurrency(_ amount: Double, showSign: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        if showSign && amount > 0 {
            return "+\(formatter.string(from: NSNumber(value: amount)) ?? "$0.00")"
        }
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    private func formatPercent(_ percent: Double) -> String {
        let sign = percent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, percent)
    }
}

// MARK: - Stock Holding Row

struct StockHoldingRow: View {
    let holding: StockHoldingModel
    let quote: StockQuote?
    let onTap: () -> Void

    private var currentPrice: Double {
        quote?.price ?? holding.averageCostPerShare
    }

    private var gainLoss: Double {
        holding.gainLoss(at: currentPrice)
    }

    private var gainLossPercent: Double {
        holding.gainLossPercent(at: currentPrice)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                symbolBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.symbol)
                        .font(.nexusHeadline)
                        .fontWeight(.semibold)

                    Text("\(formatQuantity(holding.quantity)) shares")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(holding.currentValue(at: currentPrice)))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    HStack(spacing: 4) {
                        Image(systemName: gainLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(formatGainLoss())
                    }
                    .font(.nexusCaption)
                    .foregroundStyle(gainLoss >= 0 ? Color.nexusGreen : Color.nexusRed)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
            }
        }
        .buttonStyle(.plain)
    }

    private var symbolBadge: some View {
        Text(holding.symbol.prefix(2))
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(symbolColor)
            }
    }

    private var symbolColor: Color {
        let hash = holding.symbol.hashValue
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo]
        return colors[abs(hash) % colors.count]
    }

    private func formatQuantity(_ qty: Double) -> String {
        if qty.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", qty)
        }
        return String(format: "%.4f", qty)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    private func formatGainLoss() -> String {
        let sign = gainLoss >= 0 ? "+" : ""
        return String(format: "%@$%.2f (%.1f%%)", sign, abs(gainLoss), abs(gainLossPercent))
    }
}

// MARK: - Watchlist Row

struct WatchlistRow: View {
    let item: WatchlistItemModel
    let quote: StockQuote?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                symbolBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.symbol)
                        .font(.nexusHeadline)
                        .fontWeight(.semibold)

                    Text(item.name)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let quote = quote {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(quote.formattedPrice)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))

                        HStack(spacing: 4) {
                            Image(systemName: quote.isUp ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                            Text(quote.formattedChangePercent)
                        }
                        .font(.nexusCaption)
                        .foregroundStyle(quote.isUp ? Color.nexusGreen : Color.nexusRed)
                    }
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
            }
        }
        .buttonStyle(.plain)
    }

    private var symbolBadge: some View {
        Text(item.symbol.prefix(2))
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(symbolColor)
            }
    }

    private var symbolColor: Color {
        let hash = item.symbol.hashValue
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo]
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Alerts List View

struct AlertsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StockAlertModel.createdAt, order: .reverse) private var alerts: [StockAlertModel]

    var body: some View {
        NavigationStack {
            List {
                ForEach(alerts) { alert in
                    AlertRow(alert: alert)
                }
                .onDelete(perform: deleteAlerts)
            }
            .navigationTitle("Price Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func deleteAlerts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(alerts[index])
        }
        try? modelContext.save()
    }
}

private struct AlertRow: View {
    let alert: StockAlertModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.alertType.icon)
                .font(.title2)
                .foregroundStyle(alert.isTriggered ? Color.nexusGreen : Color.nexusOrange)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.symbol)
                    .font(.nexusHeadline)

                Text("\(alert.alertType.displayName) $\(String(format: "%.2f", alert.targetPrice))")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if alert.isTriggered {
                Text("Triggered")
                    .font(.nexusCaption)
                    .foregroundStyle(.green)
            } else if !alert.isActive {
                Text("Inactive")
                    .font(.nexusCaption)
                    .foregroundStyle(.gray)
            }
        }
    }
}
