import Foundation
import SwiftData

protocol CurrencyServiceProtocol: Sendable {
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

final class CurrencyService: CurrencyServiceProtocol, Sendable {
    private let baseURL = "https://api.exchangerate-api.com/v4/latest"

    func fetchRatesFromAPI(base: Currency) async throws -> ExchangeRates {
        let url = URL(string: "\(baseURL)/\(base.rawValue)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CurrencyServiceError.requestFailed
        }

        let apiResponse = try JSONDecoder().decode(ExchangeRateAPIResponse.self, from: data)
        return ExchangeRates(
            base: base,
            rates: parseRates(apiResponse.rates),
            timestamp: Date()
        )
    }

    func convert(amount: Double, from: Currency, to: Currency, rates: ExchangeRates) -> Double {
        guard from != to else { return amount }

        if from == rates.base {
            return amount * (rates.rate(for: to) ?? 1.0)
        }

        if to == rates.base {
            return amount / (rates.rate(for: from) ?? 1.0)
        }

        let amountInBase = amount / (rates.rate(for: from) ?? 1.0)
        return amountInBase * (rates.rate(for: to) ?? 1.0)
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
}

// MARK: - API Response Model

private struct ExchangeRateAPIResponse: Codable {
    let base: String
    let date: String
    let rates: [String: Double]
}

// MARK: - Errors

enum CurrencyServiceError: Error, LocalizedError {
    case requestFailed
    case invalidResponse
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            "Failed to fetch exchange rates"
        case .invalidResponse:
            "Invalid response from server"
        case .networkUnavailable:
            "Network unavailable"
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
