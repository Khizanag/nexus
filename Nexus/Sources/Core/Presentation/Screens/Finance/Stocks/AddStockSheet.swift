import SwiftUI
import SwiftData

enum AddStockMode {
    case portfolio
    case watchlist
}

struct AddStockSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: AddStockMode

    @State private var searchText = ""
    @State private var searchResults: [StockSearchResult] = []
    @State private var isSearching = false
    @State private var selectedStock: StockSearchResult?
    @State private var showPurchaseDetails = false

    // Live quote data
    @State private var currentQuote: StockQuote?
    @State private var isLoadingQuote = false
    @State private var quoteError: String?

    // Purchase details - only shares needed now
    @State private var sharesText = ""

    private let stockService: StockService = FinnhubStockService()

    private var groupedPopular: [String: [PopularStock]] {
        Dictionary(grouping: PopularStock.all, by: { $0.sector })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showPurchaseDetails, let stock = selectedStock {
                    purchaseDetailsView(for: stock)
                } else {
                    searchBar
                    if !searchText.isEmpty {
                        searchResultsList
                    } else {
                        popularStocksList
                    }
                }
            }
            .background(Color.nexusBackground)
            .navigationTitle(mode == .portfolio ? "Add to Portfolio" : "Add to Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Search Bar

private extension AddStockSheet {
    var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search stocks...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusSurface)
            }

            if isSearching {
                ProgressView()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .onChange(of: searchText) {
            Task { await searchStocks() }
        }
    }
}

// MARK: - Search Results

private extension AddStockSheet {
    var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if searchResults.isEmpty, !isSearching, !searchText.isEmpty {
                    emptySearchState
                } else {
                    ForEach(searchResults) { result in
                        SearchResultRow(result: result) {
                            selectStock(result)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    var emptySearchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No results found")
                .font(.nexusHeadline)

            Text("Try a different search term")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

// MARK: - Popular Stocks

private extension AddStockSheet {
    var popularStocksList: some View {
        ScrollView {
            LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                ForEach(PopularStock.sectors, id: \.self) { sector in
                    if let stocks = groupedPopular[sector] {
                        Section {
                            VStack(spacing: 0) {
                                ForEach(stocks) { stock in
                                    PopularStockRow(stock: stock) {
                                        let result = StockSearchResult(
                                            symbol: stock.symbol,
                                            name: stock.name,
                                            exchange: stock.exchange,
                                            type: "Common Stock",
                                            region: "US"
                                        )
                                        selectStock(result)
                                    }

                                    if stock.id != stocks.last?.id {
                                        Divider()
                                            .background(Color.nexusBorder)
                                            .padding(.leading, 56)
                                    }
                                }
                            }
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.nexusSurface)
                            }
                        } header: {
                            SectorHeader(sector: sector)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Purchase Details View

private extension AddStockSheet {
    func purchaseDetailsView(for stock: StockSearchResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                stockHeader(for: stock)

                if isLoadingQuote {
                    loadingQuoteView
                } else if let quote = currentQuote {
                    liveQuoteCard(quote: quote)

                    if mode == .portfolio {
                        sharesInputCard(quote: quote)
                    }

                    addButton(stock: stock, quote: quote)
                } else if let error = quoteError {
                    errorView(error: error, stock: stock)
                }
            }
            .padding(20)
        }
    }

    func stockHeader(for stock: StockSearchResult) -> some View {
        HStack(spacing: 14) {
            symbolBadge(for: stock.symbol)

            VStack(alignment: .leading, spacing: 4) {
                Text(stock.symbol)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(stock.name)
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    showPurchaseDetails = false
                    selectedStock = nil
                    currentQuote = nil
                    quoteError = nil
                    sharesText = ""
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    var loadingQuoteView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Fetching live price...")
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    func liveQuoteCard(quote: StockQuote) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Live Price")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.nexusGreen)
                        .frame(width: 8, height: 8)
                    Text("Live")
                        .font(.nexusCaption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(quote.formattedPrice)
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                VStack(alignment: .leading, spacing: 2) {
                    Text(quote.formattedChange)
                        .font(.nexusSubheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(quote.isUp ? Color.nexusGreen : Color.nexusRed)

                    Text(quote.formattedChangePercent)
                        .font(.nexusCaption)
                        .foregroundStyle(quote.isUp ? Color.nexusGreen : Color.nexusRed)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Open")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    Text(formatPrice(quote.open))
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("High")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    Text(formatPrice(quote.high))
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.nexusGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Low")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    Text(formatPrice(quote.low))
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.nexusRed)
                }

                Spacer()
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [quote.isUp ? Color.nexusGreen.opacity(0.3) : Color.nexusRed.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
    }

    func sharesInputCard(quote: StockQuote) -> some View {
        VStack(spacing: 16) {
            Text("How many shares?")
                .font(.nexusHeadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                TextField("0", text: $sharesText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text("shares")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusBackground)
            }

            if let shares = Double(sharesText), shares > 0 {
                let totalCost = shares * quote.price

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Cost")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(totalCost))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("@ \(quote.formattedPrice)/share")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.nexusGreen.opacity(0.1))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
        .animation(.spring(response: 0.3), value: sharesText)
    }

    func addButton(stock: StockSearchResult, quote: StockQuote) -> some View {
        Button {
            addStock(stock, quote: quote)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: mode == .portfolio ? "plus.circle.fill" : "eye.fill")
                    .font(.system(size: 18, weight: .semibold))

                Text(mode == .portfolio ? "Add to Portfolio" : "Add to Watchlist")
                    .font(.nexusHeadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: mode == .portfolio
                                ? [Color.nexusGreen, Color.nexusGreen.opacity(0.8)]
                                : [Color.nexusPurple, Color.nexusPurple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: (mode == .portfolio ? Color.nexusGreen : Color.nexusPurple).opacity(0.3), radius: 10, y: 5)
            }
        }
        .disabled(mode == .portfolio && !isValidPurchase)
        .opacity(mode == .portfolio && !isValidPurchase ? 0.6 : 1)
    }

    func errorView(error: String, stock: StockSearchResult) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.nexusOrange)

            Text("Couldn't fetch price")
                .font(.nexusHeadline)

            Text(error)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await fetchQuote(for: stock.symbol) }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }
}

// MARK: - Actions

private extension AddStockSheet {
    var isValidPurchase: Bool {
        guard let shares = Double(sharesText) else { return false }
        return shares > 0
    }

    func searchStocks() async {
        guard searchText.count >= 1 else {
            searchResults = []
            return
        }

        isSearching = true
        do {
            searchResults = try await stockService.searchStocks(query: searchText)
        } catch {
            print("Search error: \(error)")
        }
        isSearching = false
    }

    func selectStock(_ stock: StockSearchResult) {
        selectedStock = stock

        if mode == .watchlist {
            // For watchlist, add immediately
            addToWatchlist(stock)
        } else {
            // For portfolio, show purchase details with live quote
            withAnimation(.spring(response: 0.3)) {
                showPurchaseDetails = true
            }
            Task { await fetchQuote(for: stock.symbol) }
        }
    }

    func fetchQuote(for symbol: String) async {
        isLoadingQuote = true
        quoteError = nil

        do {
            let quote = try await stockService.getQuote(symbol: symbol)
            await MainActor.run {
                currentQuote = quote
                isLoadingQuote = false
            }
        } catch {
            await MainActor.run {
                quoteError = error.localizedDescription
                isLoadingQuote = false
            }
        }
    }

    func addStock(_ stock: StockSearchResult, quote: StockQuote) {
        if mode == .portfolio {
            guard let shares = Double(sharesText), shares > 0 else { return }

            let holding = StockHoldingModel(
                symbol: stock.symbol,
                name: stock.name,
                quantity: shares,
                averageCostPerShare: quote.price,
                exchange: stock.exchange
            )
            modelContext.insert(holding)
        } else {
            addToWatchlist(stock)
            return
        }

        try? modelContext.save()
        dismiss()
    }

    func addToWatchlist(_ stock: StockSearchResult) {
        let item = WatchlistItemModel(
            symbol: stock.symbol,
            name: stock.name,
            exchange: stock.exchange
        )
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Helpers

private extension AddStockSheet {
    func symbolBadge(for symbol: String) -> some View {
        Text(symbol.prefix(2))
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [symbolColor(for: symbol), symbolColor(for: symbol).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }

    func symbolColor(for symbol: String) -> Color {
        let hash = symbol.hashValue
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo]
        return colors[abs(hash) % colors.count]
    }

    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: price)) ?? "$0.00"
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let result: StockSearchResult
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                symbolBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.symbol)
                        .font(.nexusHeadline)
                        .fontWeight(.semibold)

                    Text(result.name)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(result.exchange)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule().fill(Color.nexusBorder)
                    }

                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.nexusGreen)
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
        Text(result.symbol.prefix(2))
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(symbolColor)
            }
    }

    private var symbolColor: Color {
        let hash = result.symbol.hashValue
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo]
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Popular Stock Row

private struct PopularStockRow: View {
    let stock: PopularStock
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                symbolBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(stock.symbol)
                        .font(.nexusSubheadline)
                        .fontWeight(.semibold)

                    Text(stock.name)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(Color.nexusGreen)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var symbolBadge: some View {
        Text(stock.symbol.prefix(2))
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(sectorColor)
            }
    }

    private var sectorColor: Color {
        switch stock.sector {
        case "Technology": .blue
        case "Financial": .green
        case "Healthcare": .red
        case "Consumer Cyclical": .orange
        case "Consumer Defensive": .yellow
        case "Communication": .purple
        case "Energy": .brown
        case "ETF": .cyan
        default: .gray
        }
    }
}

// MARK: - Sector Header

private struct SectorHeader: View {
    let sector: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: sectorIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(sectorColor)

            Text(sector)
                .font(.nexusHeadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .background(Color.nexusBackground)
    }

    private var sectorIcon: String {
        switch sector {
        case "Technology": "cpu"
        case "Financial": "building.columns"
        case "Healthcare": "heart.fill"
        case "Consumer Cyclical": "cart.fill"
        case "Consumer Defensive": "basket.fill"
        case "Communication": "antenna.radiowaves.left.and.right"
        case "Energy": "bolt.fill"
        case "ETF": "chart.pie.fill"
        default: "circle.fill"
        }
    }

    private var sectorColor: Color {
        switch sector {
        case "Technology": .blue
        case "Financial": .green
        case "Healthcare": .red
        case "Consumer Cyclical": .orange
        case "Consumer Defensive": .yellow
        case "Communication": .purple
        case "Energy": .brown
        case "ETF": .cyan
        default: .gray
        }
    }
}

#Preview {
    AddStockSheet(mode: .portfolio)
        .preferredColorScheme(.dark)
}
