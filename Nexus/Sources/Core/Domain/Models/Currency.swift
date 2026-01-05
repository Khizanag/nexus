import Foundation

enum Currency: String, CaseIterable, Identifiable, Codable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case gel = "GEL"
    case chf = "CHF"
    case cad = "CAD"
    case aud = "AUD"
    case cny = "CNY"
    case inr = "INR"
    case krw = "KRW"
    case try_ = "TRY"
    case rub = "RUB"
    case brl = "BRL"
    case mxn = "MXN"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .usd: "$"
        case .eur: "€"
        case .gbp: "£"
        case .jpy: "¥"
        case .gel: "₾"
        case .chf: "Fr"
        case .cad: "C$"
        case .aud: "A$"
        case .cny: "¥"
        case .inr: "₹"
        case .krw: "₩"
        case .try_: "₺"
        case .rub: "₽"
        case .brl: "R$"
        case .mxn: "$"
        }
    }

    var name: String {
        switch self {
        case .usd: "US Dollar"
        case .eur: "Euro"
        case .gbp: "British Pound"
        case .jpy: "Japanese Yen"
        case .gel: "Georgian Lari"
        case .chf: "Swiss Franc"
        case .cad: "Canadian Dollar"
        case .aud: "Australian Dollar"
        case .cny: "Chinese Yuan"
        case .inr: "Indian Rupee"
        case .krw: "South Korean Won"
        case .try_: "Turkish Lira"
        case .rub: "Russian Ruble"
        case .brl: "Brazilian Real"
        case .mxn: "Mexican Peso"
        }
    }

    var flag: String {
        switch self {
        case .usd: "🇺🇸"
        case .eur: "🇪🇺"
        case .gbp: "🇬🇧"
        case .jpy: "🇯🇵"
        case .gel: "🇬🇪"
        case .chf: "🇨🇭"
        case .cad: "🇨🇦"
        case .aud: "🇦🇺"
        case .cny: "🇨🇳"
        case .inr: "🇮🇳"
        case .krw: "🇰🇷"
        case .try_: "🇹🇷"
        case .rub: "🇷🇺"
        case .brl: "🇧🇷"
        case .mxn: "🇲🇽"
        }
    }

    var decimalPlaces: Int {
        switch self {
        case .jpy, .krw: 0
        default: 2
        }
    }

    func format(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = rawValue
        formatter.currencySymbol = symbol
        formatter.maximumFractionDigits = decimalPlaces
        formatter.minimumFractionDigits = decimalPlaces
        return formatter.string(from: NSNumber(value: amount)) ?? "\(symbol)0"
    }
}
