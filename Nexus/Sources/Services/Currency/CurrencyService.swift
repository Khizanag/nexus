import Foundation
import SwiftData

protocol CurrencyService: Sendable {
    func fetchRatesFromAPI(base: Currency) async throws -> ExchangeRates
    func convert(amount: Double, from: Currency, to: Currency, rates: ExchangeRates) -> Double
}

struct ExchangeRates: Sendable {
    let base: Currency
    let rates: [Currency: Double]
    let timestamp: Date

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 15 * 60
    }

    func rate(for currency: Currency) -> Double? {
        if currency == base { return 1.0 }
        return rates[currency]
    }
}

final class DefaultCurrencyService: CurrencyService, Sendable {
    private let baseURL = "https://api.exchangerate-api.com/v4/latest"

    // Fallback rates (approximate) when API is unavailable - rates are relative to USD
    private static let fallbackRatesFromUSD: [Currency: Double] = [
        .usd: 1.0,
        .eur: 0.92,
        .gbp: 0.79,
        .gel: 2.75,
        .jpy: 149.0,
        .chf: 0.88,
        .cad: 1.36,
        .aud: 1.53,
        .cny: 7.24,
        .inr: 83.0,
        .krw: 1320.0,
        .try_: 32.0,
        .rub: 92.0,
        .brl: 4.97,
        .mxn: 17.2
    ]

    func fetchRatesFromAPI(base: Currency) async throws -> ExchangeRates {
        // Always fetch USD-based rates (most reliable) then convert
        guard let url = URL(string: "\(baseURL)/USD") else {
            throw CurrencyServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw CurrencyServiceError.networkUnavailable
            case .timedOut:
                throw CurrencyServiceError.timeout
            default:
                throw CurrencyServiceError.requestFailed
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CurrencyServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw CurrencyServiceError.serverError(httpResponse.statusCode)
        }

        do {
            let apiResponse = try JSONDecoder().decode(ExchangeRateAPIResponse.self, from: data)
            let usdRates = parseRates(apiResponse.rates)

            // Convert USD-based rates to the requested base currency
            let convertedRates = convertRatesToBase(usdRates: usdRates, targetBase: base)

            return ExchangeRates(
                base: base,
                rates: convertedRates,
                timestamp: Date()
            )
        } catch {
            throw CurrencyServiceError.decodingFailed
        }
    }

    /// Returns fallback rates when API is unavailable
    func getFallbackRates(base: Currency) -> ExchangeRates {
        let convertedRates = convertRatesToBase(usdRates: Self.fallbackRatesFromUSD, targetBase: base)
        return ExchangeRates(base: base, rates: convertedRates, timestamp: Date.distantPast)
    }

    func convert(amount: Double, from: Currency, to: Currency, rates: ExchangeRates) -> Double {
        guard from != to else { return amount }

        // Get rate for 'from' currency (how many 'from' per 1 base)
        let fromRate = rates.rate(for: from) ?? 1.0
        // Get rate for 'to' currency (how many 'to' per 1 base)
        let toRate = rates.rate(for: to) ?? 1.0

        // Convert: amount in 'from' -> base -> 'to'
        // If base is GEL and rates show: USD=0.36 (1 GEL = 0.36 USD)
        // To convert $20 USD to GEL: 20 / 0.36 = 55.56 GEL
        if from == rates.base {
            return amount * toRate
        }

        if to == rates.base {
            return amount / fromRate
        }

        // Cross conversion through base
        let amountInBase = amount / fromRate
        return amountInBase * toRate
    }

    private func parseRates(_ apiRates: [String: Double]) -> [Currency: Double] {
        var rates: [Currency: Double] = [:]
        for currency in Currency.allCases {
            if let rate = apiRates[currency.rawValue] {
                rates[currency] = rate
            }
        }
        return rates
    }

    /// Convert USD-based rates to any other base currency
    private func convertRatesToBase(usdRates: [Currency: Double], targetBase: Currency) -> [Currency: Double] {
        guard targetBase != .usd else { return usdRates }

        guard let targetRateFromUSD = usdRates[targetBase], targetRateFromUSD > 0 else {
            return usdRates
        }

        // If USD rates show: GEL=2.75 (1 USD = 2.75 GEL)
        // To get GEL-based rates: USD = 1/2.75 = 0.36 (1 GEL = 0.36 USD)
        var convertedRates: [Currency: Double] = [:]
        for (currency, usdRate) in usdRates {
            if currency == targetBase {
                convertedRates[currency] = 1.0
            } else {
                // rate = usdRate / targetRateFromUSD
                // e.g., EUR in GEL terms: 0.92 / 2.75 = 0.33 (1 GEL = 0.33 EUR)
                // Wait, that's wrong. Let me recalculate.
                // If 1 USD = 2.75 GEL and 1 USD = 0.92 EUR
                // Then 1 GEL = 0.92/2.75 EUR = 0.33 EUR
                // And 1 EUR in GEL = 2.75/0.92 = 2.99 GEL
                // So for GEL-based rates, we want: how many X per 1 GEL
                // USD: 1/2.75 = 0.36 (1 GEL = 0.36 USD) ✓
                // EUR: 0.92/2.75 = 0.33 (1 GEL = 0.33 EUR) ✓
                convertedRates[currency] = usdRate / targetRateFromUSD
            }
        }
        return convertedRates
    }
}

// MARK: - API Response Model

private struct ExchangeRateAPIResponse: Codable {
    let base: String
    let date: String
    let rates: [String: Double]
}

// MARK: - Errors

enum CurrencyServiceError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case invalidResponse
    case networkUnavailable
    case timeout
    case serverError(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .requestFailed:
            "Failed to fetch exchange rates"
        case .invalidResponse:
            "Invalid response from server"
        case .networkUnavailable:
            "No internet connection"
        case .timeout:
            "Request timed out"
        case .serverError(let code):
            "Server error (\(code))"
        case .decodingFailed:
            "Failed to parse rates"
        }
    }
}

// MARK: - SwiftData Cache Helpers

@MainActor
enum CurrencyCache {
    static func getCachedRates(base: Currency, context: ModelContext) -> ExchangeRates? {
        let baseCurrency = base.rawValue
        let descriptor = FetchDescriptor<CurrencyRateCacheModel>(
            predicate: #Predicate { $0.baseCurrency == baseCurrency }
        )
        guard let cached = try? context.fetch(descriptor).first else {
            return nil
        }
        return cached.toExchangeRates()
    }

    static func saveCachedRates(_ rates: ExchangeRates, context: ModelContext) {
        let baseCurrency = rates.base.rawValue
        let descriptor = FetchDescriptor<CurrencyRateCacheModel>(
            predicate: #Predicate { $0.baseCurrency == baseCurrency }
        )

        let existing = try? context.fetch(descriptor).first

        if let existing {
            var ratesDict: [String: Double] = [:]
            for (currency, rate) in rates.rates {
                ratesDict[currency.rawValue] = rate
            }
            existing.rates = ratesDict
            existing.timestamp = rates.timestamp
        } else {
            let cache = CurrencyRateCacheModel(baseCurrency: rates.base.rawValue)
            var ratesDict: [String: Double] = [:]
            for (currency, rate) in rates.rates {
                ratesDict[currency.rawValue] = rate
            }
            cache.rates = ratesDict
            cache.timestamp = rates.timestamp
            context.insert(cache)
        }

        try? context.save()
    }
}
