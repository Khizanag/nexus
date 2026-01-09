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

    // Purchase details
    @State private var quantity = ""
    @State private var pricePerShare = ""
    @State private var purchaseDate = Date()

    private let stockService: StockService = FinnhubStockService()

    private var groupedPopular: [String: [PopularStock]] {
        Dictionary(grouping: PopularStock.all, by: { $0.sector })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if showPurchaseDetails, let stock = selectedStock {
                    purchaseDetailsForm(for: stock)
                } else if !searchText.isEmpty {
                    searchResultsList
                } else {
                    popularStocksList
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

    // MARK: - Search Bar

    private var searchBar: some View {
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
            Task {
                await searchStocks()
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if searchResults.isEmpty && !isSearching && !searchText.isEmpty {
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

    private var emptySearchState: some View {
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

    // MARK: - Popular Stocks

    private var popularStocksList: some View {
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

    // MARK: - Purchase Details Form

    private func purchaseDetailsForm(for stock: StockSearchResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stock info header
                HStack(spacing: 12) {
                    symbolBadge(for: stock.symbol)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(stock.symbol)
                            .font(.nexusHeadline)
                            .fontWeight(.semibold)
                        Text(stock.name)
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        withAnimation {
                            showPurchaseDetails = false
                            selectedStock = nil
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

                if mode == .portfolio {
                    // Purchase form
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Purchase Details")
                            .font(.nexusHeadline)

                        VStack(spacing: 12) {
                            HStack {
                                Text("Shares")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("0", text: $quantity)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                            .padding(16)
                            .background(Color.nexusSurface)
                            .cornerRadius(12)

                            HStack {
                                Text("Price per Share")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("$")
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: $pricePerShare)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                            .padding(16)
                            .background(Color.nexusSurface)
                            .cornerRadius(12)

                            DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                                .padding(16)
                                .background(Color.nexusSurface)
                                .cornerRadius(12)
                        }

                        if let qty = Double(quantity), let price = Double(pricePerShare), qty > 0, price > 0 {
                            HStack {
                                Text("Total Cost")
                                    .font(.nexusSubheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatCurrency(qty * price))
                                    .font(.nexusHeadline)
                                    .fontWeight(.semibold)
                            }
                            .padding(16)
                            .background(Color.nexusSurface)
                            .cornerRadius(12)
                        }
                    }
                }

                // Add button
                Button {
                    addStock(stock)
                } label: {
                    Text(mode == .portfolio ? "Add to Portfolio" : "Add to Watchlist")
                        .font(.nexusHeadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(mode == .portfolio ? Color.nexusGreen : Color.nexusPurple)
                        }
                }
                .disabled(mode == .portfolio && !isValidPurchase)
            }
            .padding(20)
        }
    }

    private var isValidPurchase: Bool {
        guard let qty = Double(quantity), let price = Double(pricePerShare) else { return false }
        return qty > 0 && price > 0
    }

    // MARK: - Helpers

    private func searchStocks() async {
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

    private func selectStock(_ stock: StockSearchResult) {
        selectedStock = stock
        if mode == .watchlist {
            addStock(stock)
        } else {
            withAnimation(.spring(response: 0.3)) {
                showPurchaseDetails = true
            }
        }
    }

    private func addStock(_ stock: StockSearchResult) {
        if mode == .portfolio {
            guard let qty = Double(quantity), let price = Double(pricePerShare) else { return }

            let holding = StockHoldingModel(
                symbol: stock.symbol,
                name: stock.name,
                quantity: qty,
                averageCostPerShare: price,
                exchange: stock.exchange
            )
            modelContext.insert(holding)
        } else {
            let item = WatchlistItemModel(
                symbol: stock.symbol,
                name: stock.name,
                exchange: stock.exchange
            )
            modelContext.insert(item)
        }

        try? modelContext.save()
        dismiss()
    }

    private func symbolBadge(for symbol: String) -> some View {
        Text(symbol.prefix(2))
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(symbolColor(for: symbol))
            }
    }

    private func symbolColor(for symbol: String) -> Color {
        let hash = symbol.hashValue
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo]
        return colors[abs(hash) % colors.count]
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
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
