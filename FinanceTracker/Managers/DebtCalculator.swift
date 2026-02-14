import Foundation

struct DebtInstruction: Identifiable {
    let id = UUID()
    let debtorId: String
    let creditorId: String
    let amount: Double
}

class DebtCalculator {
    static let shared = DebtCalculator()
    
    private init() {}
    
    /// Converts Net Balances into specific "Who owes Who" instructions (Debt Simplification)
    /// - Parameter balances: Dictionary of [UserID: NetAmount]
    /// - Returns: List of instructions to settle debts efficiently
    func calculateDebtResolution(balances: [String: Double]) -> [DebtInstruction] {
        var debtors = balances.filter { $0.value < -0.01 }.map { ($0.key, $0.value) }.sorted { $0.1 < $1.1 } // Most negative first
        var creditors = balances.filter { $0.value > 0.01 }.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 } // Most positive first
        
        var instructions: [DebtInstruction] = []
        
        var debtorIndex = 0
        var creditorIndex = 0
        
        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let debtor = debtors[debtorIndex]
            let creditor = creditors[creditorIndex]
            
            // Amount to settle is min of what debtor owes and what creditor is owed
            let amount = min(abs(debtor.1), creditor.1)
            
            instructions.append(DebtInstruction(debtorId: debtor.0, creditorId: creditor.0, amount: amount))
            
            // Update remaining
            debtors[debtorIndex].1 += amount
            creditors[creditorIndex].1 -= amount
            
            // Move indices if settled (allow small float error)
            if abs(debtors[debtorIndex].1) < 0.01 { debtorIndex += 1 }
            if creditors[creditorIndex].1 < 0.01 { creditorIndex += 1 }
        }
        
        return instructions
    }
}
