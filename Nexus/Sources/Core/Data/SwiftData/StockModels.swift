import Foundation
import SwiftData

// MARK: - Stock Holding Model

@Model
final class StockHoldingModel {
    var id: UUID
    var symbol: String
    var name: String
    var quantity: Double
    var averageCostPerShare: Double
    var currency: String
    var exchange: String
    var sector: String?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \StockTransactionModel.holding)
    var transactions: [StockTransactionModel]?

    init(
        id: UUID = UUID(),
        symbol: String,
        name: String,
        quantity: Double,
        averageCostPerShare: Double,
        currency: String = "USD",
        exchange: String = "NASDAQ",
        sector: String? = nil,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.symbol = symbol.uppercased()
        self.name = name
        self.quantity = quantity
        self.averageCostPerShare = averageCostPerShare
        self.currency = currency
        self.exchange = exchange
        self.sector = sector
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var totalCost: Double {
        quantity * averageCostPerShare
    }

    func currentValue(at price: Double) -> Double {
        quantity * price
    }

    func gainLoss(at price: Double) -> Double {
        currentValue(at: price) - totalCost
    }

    func gainLossPercent(at price: Double) -> Double {
        guard totalCost > 0 else { return 0 }
        return (gainLoss(at: price) / totalCost) * 100
    }

    func addShares(quantity: Double, price: Double) {
        let newTotalCost = totalCost + (quantity * price)
        let newQuantity = self.quantity + quantity
        self.averageCostPerShare = newTotalCost / newQuantity
        self.quantity = newQuantity
        self.updatedAt = .now

        let transaction = StockTransactionModel(
            type: .buy,
            quantity: quantity,
            pricePerShare: price,
            holding: self
        )
        if transactions == nil {
            transactions = [transaction]
        } else {
            transactions?.append(transaction)
        }
    }

    func removeShares(quantity: Double, price: Double) -> Bool {
        guard quantity <= self.quantity else { return false }
        self.quantity -= quantity
        self.updatedAt = .now

        let transaction = StockTransactionModel(
            type: .sell,
            quantity: quantity,
            pricePerShare: price,
            holding: self
        )
        if transactions == nil {
            transactions = [transaction]
        } else {
            transactions?.append(transaction)
        }
        return true
    }
}

// MARK: - Stock Transaction Model

@Model
final class StockTransactionModel {
    var id: UUID
    var type: StockTransactionType
    var quantity: Double
    var pricePerShare: Double
    var date: Date
    var fees: Double
    var notes: String
    var holding: StockHoldingModel?

    init(
        id: UUID = UUID(),
        type: StockTransactionType,
        quantity: Double,
        pricePerShare: Double,
        date: Date = .now,
        fees: Double = 0,
        notes: String = "",
        holding: StockHoldingModel? = nil
    ) {
        self.id = id
        self.type = type
        self.quantity = quantity
        self.pricePerShare = pricePerShare
        self.date = date
        self.fees = fees
        self.notes = notes
        self.holding = holding
    }

    var totalValue: Double {
        quantity * pricePerShare
    }
}

enum StockTransactionType: String, Codable {
    case buy
    case sell
    case dividend

    var displayName: String {
        switch self {
        case .buy: "Buy"
        case .sell: "Sell"
        case .dividend: "Dividend"
        }
    }

    var icon: String {
        switch self {
        case .buy: "arrow.down.circle.fill"
        case .sell: "arrow.up.circle.fill"
        case .dividend: "dollarsign.circle.fill"
        }
    }
}

// MARK: - Watchlist Item Model

@Model
final class WatchlistItemModel {
    var id: UUID
    var symbol: String
    var name: String
    var exchange: String
    var addedAt: Date
    var targetPrice: Double?
    var notes: String

    init(
        id: UUID = UUID(),
        symbol: String,
        name: String,
        exchange: String = "NASDAQ",
        addedAt: Date = .now,
        targetPrice: Double? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.symbol = symbol.uppercased()
        self.name = name
        self.exchange = exchange
        self.addedAt = addedAt
        self.targetPrice = targetPrice
        self.notes = notes
    }
}

// MARK: - Stock Alert Model

@Model
final class StockAlertModel {
    var id: UUID
    var symbol: String
    var name: String
    var alertType: StockAlertType
    var targetPrice: Double
    var isActive: Bool
    var isTriggered: Bool
    var triggeredAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        symbol: String,
        name: String,
        alertType: StockAlertType,
        targetPrice: Double,
        isActive: Bool = true,
        isTriggered: Bool = false,
        triggeredAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.symbol = symbol.uppercased()
        self.name = name
        self.alertType = alertType
        self.targetPrice = targetPrice
        self.isActive = isActive
        self.isTriggered = isTriggered
        self.triggeredAt = triggeredAt
        self.createdAt = createdAt
    }

    func shouldTrigger(currentPrice: Double) -> Bool {
        guard isActive && !isTriggered else { return false }
        switch alertType {
        case .priceAbove:
            return currentPrice >= targetPrice
        case .priceBelow:
            return currentPrice <= targetPrice
        }
    }
}

enum StockAlertType: String, Codable {
    case priceAbove
    case priceBelow

    var displayName: String {
        switch self {
        case .priceAbove: "Price Above"
        case .priceBelow: "Price Below"
        }
    }

    var icon: String {
        switch self {
        case .priceAbove: "arrow.up.circle"
        case .priceBelow: "arrow.down.circle"
        }
    }
}

// MARK: - Stock Quote (Non-persisted)

struct StockQuote: Identifiable, Codable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let changePercent: Double
    let previousClose: Double
    let open: Double
    let high: Double
    let low: Double
    let volume: Int
    let marketCap: Double?
    let peRatio: Double?
    let dividend: Double?
    let exchange: String
    let timestamp: Date

    var isUp: Bool { change >= 0 }

    var formattedPrice: String {
        String(format: "$%.2f", price)
    }

    var formattedChange: String {
        let sign = change >= 0 ? "+" : ""
        return String(format: "%@$%.2f", sign, change)
    }

    var formattedChangePercent: String {
        let sign = changePercent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, changePercent)
    }
}

// MARK: - Stock Search Result

struct StockSearchResult: Identifiable, Codable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let exchange: String
    let type: String
    let region: String
}

// MARK: - Historical Data Point

struct StockDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let close: Double
    let volume: Int
}

// MARK: - Popular Stocks

struct PopularStock: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let exchange: String
    let sector: String

    static let all: [PopularStock] = [
        // Tech Giants
        PopularStock(symbol: "AAPL", name: "Apple Inc.", exchange: "NASDAQ", sector: "Technology"),
        PopularStock(symbol: "MSFT", name: "Microsoft Corporation", exchange: "NASDAQ", sector: "Technology"),
        PopularStock(symbol: "GOOGL", name: "Alphabet Inc.", exchange: "NASDAQ", sector: "Technology"),
        PopularStock(symbol: "AMZN", name: "Amazon.com Inc.", exchange: "NASDAQ", sector: "Consumer Cyclical"),
        PopularStock(symbol: "META", name: "Meta Platforms Inc.", exchange: "NASDAQ", sector: "Technology"),
        PopularStock(symbol: "NVDA", name: "NVIDIA Corporation", exchange: "NASDAQ", sector: "Technology"),
        PopularStock(symbol: "TSLA", name: "Tesla Inc.", exchange: "NASDAQ", sector: "Consumer Cyclical"),

        // Finance
        PopularStock(symbol: "JPM", name: "JPMorgan Chase & Co.", exchange: "NYSE", sector: "Financial"),
        PopularStock(symbol: "V", name: "Visa Inc.", exchange: "NYSE", sector: "Financial"),
        PopularStock(symbol: "MA", name: "Mastercard Inc.", exchange: "NYSE", sector: "Financial"),
        PopularStock(symbol: "BAC", name: "Bank of America", exchange: "NYSE", sector: "Financial"),

        // Healthcare
        PopularStock(symbol: "JNJ", name: "Johnson & Johnson", exchange: "NYSE", sector: "Healthcare"),
        PopularStock(symbol: "UNH", name: "UnitedHealth Group", exchange: "NYSE", sector: "Healthcare"),
        PopularStock(symbol: "PFE", name: "Pfizer Inc.", exchange: "NYSE", sector: "Healthcare"),

        // Consumer
        PopularStock(symbol: "KO", name: "Coca-Cola Company", exchange: "NYSE", sector: "Consumer Defensive"),
        PopularStock(symbol: "PEP", name: "PepsiCo Inc.", exchange: "NASDAQ", sector: "Consumer Defensive"),
        PopularStock(symbol: "WMT", name: "Walmart Inc.", exchange: "NYSE", sector: "Consumer Defensive"),
        PopularStock(symbol: "MCD", name: "McDonald's Corporation", exchange: "NYSE", sector: "Consumer Cyclical"),
        PopularStock(symbol: "NKE", name: "Nike Inc.", exchange: "NYSE", sector: "Consumer Cyclical"),
        PopularStock(symbol: "DIS", name: "Walt Disney Company", exchange: "NYSE", sector: "Communication"),

        // Energy
        PopularStock(symbol: "XOM", name: "Exxon Mobil", exchange: "NYSE", sector: "Energy"),

        // ETFs & Indices
        PopularStock(symbol: "SPY", name: "SPDR S&P 500 ETF", exchange: "NYSE", sector: "ETF"),
        PopularStock(symbol: "QQQ", name: "Invesco QQQ Trust", exchange: "NASDAQ", sector: "ETF"),
        PopularStock(symbol: "VTI", name: "Vanguard Total Stock Market", exchange: "NYSE", sector: "ETF"),
        PopularStock(symbol: "VOO", name: "Vanguard S&P 500 ETF", exchange: "NYSE", sector: "ETF"),

        // Crypto-related
        PopularStock(symbol: "COIN", name: "Coinbase Global", exchange: "NASDAQ", sector: "Financial"),
    ]

    static func forSector(_ sector: String) -> [PopularStock] {
        all.filter { $0.sector == sector }
    }

    static var sectors: [String] {
        Array(Set(all.map { $0.sector })).sorted()
    }
}
