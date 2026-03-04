import Testing
@testable import FinanceTracker

@Suite struct DebtCalculatorTests {
    
    @Test("Basic debt resolution with one debtor and one creditor")
    func testBasicDebtResolution() {
        let balances = ["A": -100.0, "B": 100.0]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        
        #expect(result.count == 1)
        #expect(result[0].debtorId == "A")
        #expect(result[0].creditorId == "B")
        #expect(result[0].amount == 100.0)
    }

    @Test("Three-way debt resolves efficiently")
    func testThreeWayDebtResolution() {
        let balances = ["A": -60.0, "B": -40.0, "C": 100.0]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        
        #expect(result.count == 2)
        let totalSettled = result.reduce(0) { $0 + $1.amount }
        #expect(totalSettled == 100.0)
        #expect(result.allSatisfy { $0.creditorId == "C" })
    }

    @Test("Multi-currency debt resolution processes all currencies independently")
    func testMultiCurrencyResolution() {
        let balancesByCurrency = [
            "USD": ["A": -100.0, "B": 100.0],
            "EUR": ["A": 50.0, "B": -50.0]
        ]
        
        let result = DebtCalculator.shared.calculateMultiCurrencyResolution(balancesByCurrency: balancesByCurrency)
        
        #expect(result.count == 2)

        let usdInstruction = result.first { $0.currency == "USD" }
        #expect(usdInstruction != nil)
        #expect(usdInstruction?.debtorId == "A")
        #expect(usdInstruction?.creditorId == "B")
        #expect(usdInstruction?.amount == 100.0)

        let eurInstruction = result.first { $0.currency == "EUR" }
        #expect(eurInstruction != nil)
        #expect(eurInstruction?.debtorId == "B")
        #expect(eurInstruction?.creditorId == "A")
        #expect(eurInstruction?.amount == 50.0)
    }
    
    @Test("Ignore negligible balances under threshold")
    func testNegligibleBalances() {
        let balances = ["A": -0.001, "B": 0.001]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        
        #expect(result.isEmpty)
    }
}
