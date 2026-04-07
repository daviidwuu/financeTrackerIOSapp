import Foundation

enum CurrencyFormatter {
    /// "$12.34" — absolute value, no sign
    static func format(_ amount: Double, symbol: String = "$") -> String {
        String(format: "%@%.2f", symbol, abs(amount))
    }

    static func format(_ amount: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: abs(amount)))
            ?? String(format: "%@ %.2f", currencyCode, abs(amount))
    }

    /// "+$12.34" for income, "$12.34" for expense
    static func formatSigned(_ amount: Double, symbol: String = "$") -> String {
        String(format: "%@%@%.2f", amount > 0 ? "+" : "", symbol, abs(amount))
    }

    static func formatSigned(_ amount: Double, currencyCode: String) -> String {
        let base = format(amount, currencyCode: currencyCode)
        return amount > 0 ? "+\(base)" : base
    }

    /// "+USD 12.34" — for foreign currency secondary display
    static func formatForeign(_ amount: Double, currencyCode: String, signed: Bool = true) -> String {
        String(format: "%@%@ %.2f", signed && amount > 0 ? "+" : "", currencyCode, abs(amount))
    }
}
