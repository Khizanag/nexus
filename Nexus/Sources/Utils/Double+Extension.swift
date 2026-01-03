import Foundation

extension Double {
    func formatted(as style: NumberFormatter.Style, currency: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = style
        if style == .currency {
            formatter.currencyCode = currency
        }
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
