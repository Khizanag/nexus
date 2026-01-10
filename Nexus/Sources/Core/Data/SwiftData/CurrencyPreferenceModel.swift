import Foundation
import SwiftData

@Model
final class CurrencyPreferenceModel {
    var id: String = "currency_preferences"
    var favoriteCurrenciesData: Data = Data()

    init() {
        self.id = "currency_preferences"
        self.favoriteCurrenciesData = Data()
    }

    var favoriteCurrencies: [Currency] {
        get {
            guard let codes = try? JSONDecoder().decode([String].self, from: favoriteCurrenciesData) else {
                return [.usd, .eur, .gel]
            }
            return codes.compactMap { Currency(rawValue: $0) }
        }
        set {
            let codes = newValue.map { $0.rawValue }
            favoriteCurrenciesData = (try? JSONEncoder().encode(codes)) ?? Data()
        }
    }

    func isFavorite(_ currency: Currency) -> Bool {
        favoriteCurrencies.contains(currency)
    }

    func toggleFavorite(_ currency: Currency) {
        var current = favoriteCurrencies
        if let index = current.firstIndex(of: currency) {
            current.remove(at: index)
        } else {
            current.append(currency)
        }
        favoriteCurrencies = current
    }
}
