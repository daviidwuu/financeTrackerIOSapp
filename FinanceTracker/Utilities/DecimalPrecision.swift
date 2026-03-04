import Foundation

/// Shared financial precision utilities following DebtCalculator's proven pattern.
/// Accepts Double at boundaries, uses Decimal internally, rounds to 2 decimal places.
enum DecimalPrecision {

    private static let roundingHandler = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: 2,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )

    /// Rounds a Double to 2 decimal places using Decimal arithmetic.
    static func round(_ value: Double, scale: Int16 = 2) -> Double {
        let handler = scale == 2 ? roundingHandler : NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: scale,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        return NSDecimalNumber(decimal: Decimal(value))
            .rounding(accordingToBehavior: handler)
            .doubleValue
    }

    /// Sums an array of Doubles using Decimal accumulation to avoid floating-point drift.
    static func sum(_ values: [Double]) -> Double {
        let total = values.reduce(Decimal.zero) { $0 + Decimal($1) }
        return NSDecimalNumber(decimal: total)
            .rounding(accordingToBehavior: roundingHandler)
            .doubleValue
    }

    /// Subtracts b from a using Decimal arithmetic.
    static func subtract(_ a: Double, _ b: Double) -> Double {
        let result = Decimal(a) - Decimal(b)
        return NSDecimalNumber(decimal: result)
            .rounding(accordingToBehavior: roundingHandler)
            .doubleValue
    }

    /// Multiplies two Doubles using Decimal arithmetic.
    static func multiply(_ a: Double, _ b: Double) -> Double {
        let result = Decimal(a) * Decimal(b)
        return NSDecimalNumber(decimal: result)
            .rounding(accordingToBehavior: roundingHandler)
            .doubleValue
    }

    /// Divides a by b using Decimal arithmetic. Returns 0 if b is zero.
    static func divide(_ a: Double, _ b: Double) -> Double {
        guard b != 0 else { return 0 }
        let result = Decimal(a) / Decimal(b)
        return NSDecimalNumber(decimal: result)
            .rounding(accordingToBehavior: roundingHandler)
            .doubleValue
    }
}
