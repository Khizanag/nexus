import Foundation
import SwiftData

@Model
final class CurrencyRateCacheModel {
    var baseCurrency: String
    var ratesData: Data
    var timestamp: Date

    init(baseCurrency: String, ratesData: Data = Data(), timestamp: Date = .now) {
        self.baseCurrency = baseCurrency
        self.ratesData = ratesData
        self.timestamp = timestamp
    }

    var rates: [String: Double] {
        get {
            (try? JSONDecoder().decode([String: Double].self, from: ratesData)) ?? [:]
        }
        set {
            ratesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 15 * 60
    }

    func toExchangeRates() -> ExchangeRates? {
        guard let base = Currency(rawValue: baseCurrency) else { return nil }
        var currencyRates: [Currency: Double] = [:]
        for (key, value) in rates {
            if let currency = Currency(rawValue: key) {
                currencyRates[currency] = value
            }
        }
        return ExchangeRates(base: base, rates: currencyRates, timestamp: timestamp)
    }
}
