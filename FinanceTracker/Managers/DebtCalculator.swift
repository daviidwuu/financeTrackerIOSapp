import Foundation

/// Thread-safe debt resolution using Decimal for financial precision
class DebtCalculator {
    static let shared = DebtCalculator()
    
    // MARK: - Memoization
    
    /// Hashable wrapper for a dictionary of balances to use as a cache key
    struct BalanceCacheKey: Hashable {
        let keys: [String]
        let values: [Double]
        
        init(_ balances: [String: Double]) {
            let sorted = balances.sorted { $0.key < $1.key }
            self.keys = sorted.map { $0.key }
            self.values = sorted.map { $0.value }
        }
    }
    
    /// Hashable wrapper for multi-currency balances
    struct MultiCurrencyCacheKey: Hashable {
        let currencies: [String: BalanceCacheKey]
        
        init(_ balances: [String: [String: Double]]) {
            var result: [String: BalanceCacheKey] = [:]
            for (key, value) in balances {
                result[key] = BalanceCacheKey(value)
            }
            self.currencies = result
        }
    }
    
    private let singleCurrencyMemoizer = Memoization<BalanceCacheKey, [DebtInstruction]>()
    private let multiCurrencyMemoizer = Memoization<MultiCurrencyCacheKey, [DebtInstruction]>()
    
    /// Clears all memoized calculations. Call this if memory needs to be freed.
    func clearCache() {
        singleCurrencyMemoizer.clear()
        multiCurrencyMemoizer.clear()
    }
    
    // MARK: - DebtInstruction

    struct DebtInstruction: Identifiable, Equatable {
        var id = UUID()
        let debtorId: String
        let creditorId: String
        let amount: Double // Keep as Double for UI compatibility
        var currency: String = "" // FIX 1.3: Currency for this instruction (empty = default/main)
    }

    // MARK: - Single-Currency Resolution

    /// FIX #4: Uses Decimal internally to avoid floating-point precision errors.
    /// Results are rounded to 2 decimal places before returning.
    func calculateDebtResolution(balances: [String: Double]) -> [DebtInstruction] {
        let key = BalanceCacheKey(balances)
        return singleCurrencyMemoizer.get(for: key) { _ in
            self.performDebtResolution(balances: balances)
        }
    }
    
    private func performDebtResolution(balances: [String: Double]) -> [DebtInstruction] {
        // Convert to Decimal for precision
        var debtors = balances.filter { $0.value < -0.01 }
            .map { ($0.key, Decimal($0.value)) }
            .sorted { $0.1 < $1.1 } // Most negative first
        
        var creditors = balances.filter { $0.value > 0.01 }
            .map { ($0.key, Decimal($0.value)) }
            .sorted { $0.1 > $1.1 } // Most positive first
        
        var instructions: [DebtInstruction] = []
        var debtorIndex = 0
        var creditorIndex = 0
        
        let threshold: Decimal = 0.01
        
        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let debtAmount = -debtors[debtorIndex].1 // Make positive
            let creditAmount = creditors[creditorIndex].1
            let settleAmount = min(debtAmount, creditAmount)
            
            if settleAmount > threshold {
                // Round to 2 decimal places via DecimalPrecision for consistency
                let rounded = DecimalPrecision.round(NSDecimalNumber(decimal: settleAmount).doubleValue)

                instructions.append(DebtInstruction(
                    debtorId: debtors[debtorIndex].0,
                    creditorId: creditors[creditorIndex].0,
                    amount: rounded
                ))
            }
            
            debtors[debtorIndex].1 += settleAmount // Move towards zero
            creditors[creditorIndex].1 -= settleAmount
            
            // Move indices if settled (using Decimal comparison)
            if abs(debtors[debtorIndex].1) < threshold { debtorIndex += 1 }
            if creditors[creditorIndex].1 < threshold { creditorIndex += 1 }
        }
        
        return instructions
    }
    
    // MARK: - Multi-Currency Resolution

    /// FIX 1.3: Multi-currency debt resolution — runs the algorithm per currency and tags each instruction.
    func calculateMultiCurrencyResolution(balancesByCurrency: [String: [String: Double]]) -> [DebtInstruction] {
        let key = MultiCurrencyCacheKey(balancesByCurrency)
        return multiCurrencyMemoizer.get(for: key) { _ in
            self.performMultiCurrencyResolution(balancesByCurrency: balancesByCurrency)
        }
    }
    
    private func performMultiCurrencyResolution(balancesByCurrency: [String: [String: Double]]) -> [DebtInstruction] {
        var allInstructions: [DebtInstruction] = []
        for (currency, balances) in balancesByCurrency {
            let instructions = calculateDebtResolution(balances: balances)
            allInstructions.append(contentsOf: instructions.map {
                var tagged = $0
                tagged.currency = currency
                return tagged
            })
        }
        return allInstructions
    }
}

// Top-level typealias for backward compatibility
typealias DebtInstruction = DebtCalculator.DebtInstruction

// Helper: abs for Decimal
private func abs(_ value: Decimal) -> Decimal {
    return value < 0 ? -value : value
}
