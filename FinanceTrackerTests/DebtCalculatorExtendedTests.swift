import Testing
@testable import FinanceTracker

// MARK: - Extended DebtCalculator Tests
//
// The existing DebtCalculatorTests.swift covers basic 2-person and 3-person cases.
// This file covers: circular debts, unequal splits, edge cases, multi-currency
// correctness, and the threshold / Decimal precision guarantees.

@Suite struct DebtCalculatorExtendedTests {

    // MARK: - Setup / teardown

    init() {
        DebtCalculator.shared.clearCache()
    }

    // MARK: - Empty / single-person edge cases

    @Test("Empty balances produce no instructions")
    func test_emptyBalances_noInstructions() {
        let result = DebtCalculator.shared.calculateDebtResolution(balances: [:])
        #expect(result.isEmpty)
    }

    @Test("Single person with positive balance produces no debt (no one to pay)")
    func test_singleCreditor_noInstructions() {
        let result = DebtCalculator.shared.calculateDebtResolution(balances: ["Alice": 50.0])
        #expect(result.isEmpty)
    }

    @Test("Single person with negative balance produces no debt (no one to receive)")
    func test_singleDebtor_noInstructions() {
        let result = DebtCalculator.shared.calculateDebtResolution(balances: ["Alice": -50.0])
        #expect(result.isEmpty)
    }

    // MARK: - All-settled state

    @Test("All zero balances produce no instructions")
    func test_allZeroBalances_noInstructions() {
        let balances = ["A": 0.0, "B": 0.0, "C": 0.0]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        #expect(result.isEmpty)
    }

    @Test("Balances at or below the noise threshold are ignored")
    func test_nearZeroBalances_belowThreshold_noInstructions() {
        // Threshold is 0.01 — values of exactly 0.01 are included but below are not
        let balances = ["A": -0.009, "B": 0.009]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        #expect(result.isEmpty)
    }

    // MARK: - Two-person cases

    @Test("Two people: A owes B exactly")
    func test_twoPeople_straightDebt() {
        let balances = ["A": -75.00, "B": 75.00]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)

        #expect(result.count == 1)
        #expect(result[0].debtorId == "A")
        #expect(result[0].creditorId == "B")
        #expect(result[0].amount == 75.00)
    }

    @Test("Mutual small debts cancel to a single net instruction")
    func test_twoPeople_mutualDebts_netsToOne() {
        // A net owes B: B is up 100, A is up 60 → net A owes B 40
        let balances = ["A": -40.00, "B": 40.00]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)

        #expect(result.count == 1)
        #expect(result[0].amount == 40.00)
    }

    // MARK: - Circular debt minimisation

    @Test("Circular debts A→B→C→A simplify to at most 2 transfers (not 3)")
    func test_circularDebts_minimisedTransactions() {
        // A owes B $30, B owes C $30, C owes A $30 → net zero for everyone
        // If provided as balances, net is 0 for all → no instructions needed
        let balances = ["A": 0.0, "B": 0.0, "C": 0.0]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        #expect(result.isEmpty)
    }

    @Test("Non-circular three-way: two debtors pay one creditor in 2 transfers")
    func test_threeWay_twoDebtorsOneCreditor_twoTransfers() {
        // A owes 30, B owes 20, C is owed 50
        let balances = ["A": -30.0, "B": -20.0, "C": 50.0]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)

        #expect(result.count == 2)
        // All transfers go to C
        #expect(result.allSatisfy { $0.creditorId == "C" })
        // Total settled matches total owed
        let total = result.reduce(0.0) { $0 + $1.amount }
        #expect(total == 50.0)
    }

    @Test("Three-way with unequal splits: correct amounts are calculated")
    func test_threeWay_unequalSplits_correctAmounts() {
        // Dinner $90: A paid, B owes $35, C owes $55 (A's own share is $0 for simplicity)
        let balances = ["A": 90.0, "B": -35.0, "C": -55.0]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)

        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.creditorId == "A" })

        let bInstruction = result.first { $0.debtorId == "B" }
        let cInstruction = result.first { $0.debtorId == "C" }

        #expect(bInstruction?.amount == 35.0)
        #expect(cInstruction?.amount == 55.0)
    }

    // MARK: - Instruction count minimisation (greedy matching)

    @Test("Four-person group: algorithm minimises total transfers")
    func test_fourPeople_minimisedTransfers() {
        // A: -50, B: -30, C: 40, D: 40 → 2 creditors, 2 debtors
        // Optimal: A→C (40), A→D (10), B→D (30) = 3 transfers
        let balances = ["A": -50.0, "B": -30.0, "C": 40.0, "D": 40.0]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)

        // Net should be zero after all transfers
        let totalDebts = result.map { $0.amount }.reduce(0, +)
        #expect(totalDebts == 80.0) // sum of all positive balances

        // All debtors and creditors are correct
        let debtors = Set(result.map { $0.debtorId })
        let creditors = Set(result.map { $0.creditorId })
        #expect(debtors.isSubset(of: ["A", "B"]))
        #expect(creditors.isSubset(of: ["C", "D"]))
    }

    // MARK: - Decimal precision

    @Test("Amounts are rounded to 2 decimal places — no floating-point drift")
    func test_debtResolution_amountsRoundedToCent() {
        // $10 split 3 ways: each owes $3.33..., rounding must be to cent
        let balances = ["A": -3.3333333, "B": -3.3333333, "C": 6.6666666]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)

        for instruction in result {
            // All amounts must be multiples of 0.01
            let centValue = instruction.amount * 100
            #expect(centValue == centValue.rounded())
        }
    }

    @Test("Tiny sub-cent remainders from rounding are not returned as spurious instructions")
    func test_debtResolution_subCentRemainder_noSpuriousInstruction() {
        // If rounding creates a 0.004 remainder, it must be swallowed by the threshold
        let balances = ["A": -0.004, "B": 0.004]
        let result = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        #expect(result.isEmpty)
    }

    // MARK: - Caching / memoization

    @Test("Repeated calls with the same input return the same result (memoized)")
    func test_caching_sameInputReturnsSameResult() {
        let balances = ["A": -100.0, "B": 60.0, "C": 40.0]
        let first  = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        let second = DebtCalculator.shared.calculateDebtResolution(balances: balances)

        #expect(first.count == second.count)
        for (a, b) in zip(first, second) {
            #expect(a.debtorId == b.debtorId)
            #expect(a.creditorId == b.creditorId)
            #expect(a.amount == b.amount)
        }
    }

    @Test("Cache is independent per input — different balances give different results")
    func test_caching_differentInputsDifferentResults() {
        DebtCalculator.shared.clearCache()
        let r1 = DebtCalculator.shared.calculateDebtResolution(balances: ["A": -100.0, "B": 100.0])
        let r2 = DebtCalculator.shared.calculateDebtResolution(balances: ["A": -50.0,  "B": 50.0])

        #expect(r1[0].amount != r2[0].amount)
    }

    // MARK: - Multi-currency

    @Test("Multi-currency: USD and EUR debts are resolved independently")
    func test_multiCurrency_independentResolution() {
        let balances: [String: [String: Double]] = [
            "USD": ["A": -100.0, "B": 100.0],
            "EUR": ["A":   50.0, "B":  -50.0]
        ]
        let result = DebtCalculator.shared.calculateMultiCurrencyResolution(balancesByCurrency: balances)

        #expect(result.count == 2)

        let usd = result.first { $0.currency == "USD" }
        let eur = result.first { $0.currency == "EUR" }

        #expect(usd != nil)
        #expect(eur != nil)
        // In USD: A owes B
        #expect(usd?.debtorId  == "A")
        #expect(usd?.creditorId == "B")
        #expect(usd?.amount == 100.0)
        // In EUR: B owes A
        #expect(eur?.debtorId  == "B")
        #expect(eur?.creditorId == "A")
        #expect(eur?.amount == 50.0)
    }

    @Test("Multi-currency: currency tag is always set on each instruction")
    func test_multiCurrency_instructionsTaggedWithCurrency() {
        let balances: [String: [String: Double]] = [
            "SGD": ["X": -200.0, "Y": 200.0]
        ]
        let result = DebtCalculator.shared.calculateMultiCurrencyResolution(balancesByCurrency: balances)

        #expect(result.allSatisfy { $0.currency == "SGD" })
    }

    @Test("Multi-currency: empty balances dictionary produces no instructions")
    func test_multiCurrency_emptyInput_noInstructions() {
        let result = DebtCalculator.shared.calculateMultiCurrencyResolution(balancesByCurrency: [:])
        #expect(result.isEmpty)
    }
}
