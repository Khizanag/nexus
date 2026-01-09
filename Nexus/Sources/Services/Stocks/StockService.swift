import Foundation

protocol StockService: Sendable {
    func getQuote(symbol: String) async throws -> StockQuote
    func getQuotes(symbols: [String]) async throws -> [StockQuote]
    func searchStocks(query: String) async throws -> [StockSearchResult]
    func getHistoricalData(symbol: String, range: HistoricalRange) async throws -> [StockDataPoint]
}

enum HistoricalRange: String, CaseIterable {
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case year = "1Y"
    case fiveYears = "5Y"

    var displayName: String { rawValue }

    var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .year: 365
        case .fiveYears: 1825
        }
    }
}

enum StockServiceError: Error, LocalizedError {
    case invalidSymbol
    case rateLimitExceeded
    case networkError
    case parsingError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidSymbol: "Invalid stock symbol"
        case .rateLimitExceeded: "API rate limit exceeded. Please try again later."
        case .networkError: "Network error. Please check your connection."
        case .parsingError: "Failed to parse response"
        case .apiError(let message): message
        }
    }
}

// MARK: - Finnhub Implementation

final class FinnhubStockService: StockService, @unchecked Sendable {
    private let apiKey: String
    private let baseURL = "https://finnhub.io/api/v1"
    private let session: URLSession
    private var quoteCache: [String: (quote: StockQuote, timestamp: Date)] = [:]
    private let cacheDuration: TimeInterval = 60

    init(apiKey: String = "") {
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    func getQuote(symbol: String) async throws -> StockQuote {
        if let cached = quoteCache[symbol],
           Date().timeIntervalSince(cached.timestamp) < cacheDuration {
            return cached.quote
        }

        if apiKey.isEmpty {
            return generateMockQuote(symbol: symbol)
        }

        let url = URL(string: "\(baseURL)/quote?symbol=\(symbol)&token=\(apiKey)")!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockServiceError.networkError
        }

        if httpResponse.statusCode == 429 {
            throw StockServiceError.rateLimitExceeded
        }

        guard httpResponse.statusCode == 200 else {
            throw StockServiceError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let finnhubQuote = try decoder.decode(FinnhubQuote.self, from: data)

        guard finnhubQuote.c > 0 else {
            throw StockServiceError.invalidSymbol
        }

        let quote = finnhubQuote.toStockQuote(symbol: symbol)
        quoteCache[symbol] = (quote, Date())
        return quote
    }

    func getQuotes(symbols: [String]) async throws -> [StockQuote] {
        try await withThrowingTaskGroup(of: StockQuote?.self) { group in
            for symbol in symbols {
                group.addTask {
                    try? await self.getQuote(symbol: symbol)
                }
            }

            var quotes: [StockQuote] = []
            for try await quote in group {
                if let quote = quote {
                    quotes.append(quote)
                }
            }
            return quotes
        }
    }

    func searchStocks(query: String) async throws -> [StockSearchResult] {
        if apiKey.isEmpty {
            return searchMockStocks(query: query)
        }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/search?q=\(encoded)&token=\(apiKey)")!
        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(FinnhubSearchResponse.self, from: data)

        return searchResponse.result.prefix(15).map { item in
            StockSearchResult(
                symbol: item.symbol,
                name: item.description,
                exchange: item.displaySymbol.components(separatedBy: ":").first ?? "US",
                type: item.type,
                region: "US"
            )
        }
    }

    func getHistoricalData(symbol: String, range: HistoricalRange) async throws -> [StockDataPoint] {
        if apiKey.isEmpty {
            return generateMockHistoricalData(symbol: symbol, range: range)
        }

        let to = Int(Date().timeIntervalSince1970)
        let from = to - (range.days * 24 * 60 * 60)
        let resolution = range == .day ? "5" : (range == .week ? "60" : "D")

        let url = URL(string: "\(baseURL)/stock/candle?symbol=\(symbol)&resolution=\(resolution)&from=\(from)&to=\(to)&token=\(apiKey)")!
        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        let candles = try decoder.decode(FinnhubCandles.self, from: data)

        guard candles.s == "ok", let closes = candles.c, let timestamps = candles.t, let volumes = candles.v else {
            return generateMockHistoricalData(symbol: symbol, range: range)
        }

        return zip(zip(timestamps, closes), volumes).map { item in
            StockDataPoint(
                date: Date(timeIntervalSince1970: TimeInterval(item.0.0)),
                close: item.0.1,
                volume: item.1
            )
        }
    }

    // MARK: - Mock Data

    private func generateMockQuote(symbol: String) -> StockQuote {
        let popular = PopularStock.all.first { $0.symbol == symbol }
        let name = popular?.name ?? symbol

        let basePrice: Double
        switch symbol {
        case "AAPL": basePrice = 178.50
        case "MSFT": basePrice = 378.25
        case "GOOGL": basePrice = 141.80
        case "AMZN": basePrice = 178.90
        case "META": basePrice = 505.75
        case "NVDA": basePrice = 875.30
        case "TSLA": basePrice = 248.50
        case "JPM": basePrice = 195.40
        case "V": basePrice = 275.80
        case "SPY": basePrice = 512.30
        case "QQQ": basePrice = 438.50
        default: basePrice = Double.random(in: 50...500)
        }

        let changePercent = Double.random(in: -3...3)
        let change = basePrice * (changePercent / 100)
        let price = basePrice + change

        return StockQuote(
            symbol: symbol,
            name: name,
            price: price,
            change: change,
            changePercent: changePercent,
            previousClose: basePrice,
            open: basePrice + Double.random(in: -1...1),
            high: price + Double.random(in: 0...2),
            low: price - Double.random(in: 0...2),
            volume: Int.random(in: 10_000_000...100_000_000),
            marketCap: price * Double.random(in: 1_000_000_000...3_000_000_000_000),
            peRatio: Double.random(in: 10...50),
            dividend: Double.random(in: 0...3),
            exchange: popular?.exchange ?? "NASDAQ",
            timestamp: Date()
        )
    }

    private func generateMockHistoricalData(symbol: String, range: HistoricalRange) -> [StockDataPoint] {
        let quote = generateMockQuote(symbol: symbol)
        let currentPrice = quote.price
        var points: [StockDataPoint] = []

        let dataPoints: Int
        switch range {
        case .day: dataPoints = 78 // 5-min intervals
        case .week: dataPoints = 35 // Hourly
        case .month: dataPoints = 22 // Daily (trading days)
        case .threeMonths: dataPoints = 65
        case .year: dataPoints = 252
        case .fiveYears: dataPoints = 260
        }

        var price = currentPrice * Double.random(in: 0.7...0.95)

        for i in 0..<dataPoints {
            let daysAgo = Double(dataPoints - i) * (Double(range.days) / Double(dataPoints))
            let date = Calendar.current.date(byAdding: .day, value: -Int(daysAgo), to: Date()) ?? Date()

            let dailyChange = Double.random(in: -0.03...0.035)
            price = price * (1 + dailyChange)
            price = max(price, currentPrice * 0.5)
            price = min(price, currentPrice * 1.5)

            points.append(StockDataPoint(
                date: date,
                close: price,
                volume: Int.random(in: 10_000_000...80_000_000)
            ))
        }

        if let last = points.last {
            points[points.count - 1] = StockDataPoint(
                date: last.date,
                close: currentPrice,
                volume: last.volume
            )
        }

        return points
    }

    private func searchMockStocks(query: String) -> [StockSearchResult] {
        let lowercased = query.lowercased()
        return PopularStock.all
            .filter {
                $0.symbol.lowercased().contains(lowercased) ||
                $0.name.lowercased().contains(lowercased)
            }
            .prefix(10)
            .map {
                StockSearchResult(
                    symbol: $0.symbol,
                    name: $0.name,
                    exchange: $0.exchange,
                    type: "Common Stock",
                    region: "US"
                )
            }
    }
}

// MARK: - Finnhub API Response Types

private struct FinnhubQuote: Codable {
    let c: Double  // Current price
    let d: Double  // Change
    let dp: Double // Percent change
    let h: Double  // High
    let l: Double  // Low
    let o: Double  // Open
    let pc: Double // Previous close
    let t: Int     // Timestamp

    func toStockQuote(symbol: String) -> StockQuote {
        let popular = PopularStock.all.first { $0.symbol == symbol }
        return StockQuote(
            symbol: symbol,
            name: popular?.name ?? symbol,
            price: c,
            change: d,
            changePercent: dp,
            previousClose: pc,
            open: o,
            high: h,
            low: l,
            volume: 0,
            marketCap: nil,
            peRatio: nil,
            dividend: nil,
            exchange: popular?.exchange ?? "US",
            timestamp: Date(timeIntervalSince1970: TimeInterval(t))
        )
    }
}

private struct FinnhubSearchResponse: Codable {
    let count: Int
    let result: [FinnhubSearchItem]
}

private struct FinnhubSearchItem: Codable {
    let description: String
    let displaySymbol: String
    let symbol: String
    let type: String
}

private struct FinnhubCandles: Codable {
    let c: [Double]?  // Close prices
    let h: [Double]?  // High prices
    let l: [Double]?  // Low prices
    let o: [Double]?  // Open prices
    let t: [Int]?     // Timestamps
    let v: [Int]?     // Volumes
    let s: String     // Status
}
