import Foundation

/// Thread-safe debt resolution using Decimal for financial precision
class DebtCalculator {
    static let shared = DebtCalculator()
    
    struct DebtInstruction: Identifiable, Equatable {
        var id = UUID()
        let debtorId: String
        let creditorId: String
        let amount: Double // Keep as Double for UI compatibility
        var currency: String = "" // FIX 1.3: Currency for this instruction (empty = default/main)
    }
    
    /// FIX #4: Uses Decimal internally to avoid floating-point precision errors.
    /// Results are rounded to 2 decimal places before returning.
    func calculateDebtResolution(balances: [String: Double]) -> [DebtInstruction] {
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
                // Round to 2 decimal places
                let rounded = NSDecimalNumber(decimal: settleAmount)
                    .rounding(accordingToBehavior: NSDecimalNumberHandler(
                        roundingMode: .plain,
                        scale: 2,
                        raiseOnExactness: false,
                        raiseOnOverflow: false,
                        raiseOnUnderflow: false,
                        raiseOnDivideByZero: false
                    ))
                
                instructions.append(DebtInstruction(
                    debtorId: debtors[debtorIndex].0,
                    creditorId: creditors[creditorIndex].0,
                    amount: rounded.doubleValue
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
    
    /// FIX 1.3: Multi-currency debt resolution — runs the algorithm per currency and tags each instruction.
    func calculateMultiCurrencyResolution(balancesByCurrency: [String: [String: Double]]) -> [DebtInstruction] {
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
