import Foundation

/// Centralized currency/amount input parsing.
/// Replaces scattered `Double(amount)` and comma-normalization logic
/// across all form views.
enum CurrencyInput {
    
    /// Normalizes and parses an amount string.
    /// Handles commas as decimal separators, trims whitespace, and
    /// rejects non-numeric input.
    /// - Returns: Parsed Double, or nil if invalid.
    static func parse(_ string: String) -> Double? {
        let normalized = string
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        
        return Double(normalized)
    }
    
    /// Returns true if the string represents a valid, positive amount.
    static func isValid(_ string: String) -> Bool {
        guard let value = parse(string) else { return false }
        return value > 0
    }
    
    /// Parses the string, returning 0 if invalid. Use for non-critical
    /// display contexts where a fallback is acceptable.
    static func parseOrZero(_ string: String) -> Double {
        parse(string) ?? 0
    }
}
