import Testing
import Foundation
@testable import FinanceTracker

// MARK: - Budget Logic Tests
//
// Tests CategoryBudget computed amounts (remaining, spent, gross spent,
// reimbursed), BudgetPeriodCalculator window calculations, and
// WalletLogic financial helpers.
// All tests use injected transactions and dates — no Firestore required.

@Suite struct BudgetLogicTests {

    // MARK: - Helpers

    private func makeExpense(id: String? = nil, categoryId: String? = nil, amount: Double, daysAgo: Int = 0) -> FirestoreModels.TransactionModel {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return FirestoreModels.TransactionModel(
            id: id,
            userId: "u1",
            title: "Test Expense",
            categoryId: categoryId,
            amount: -abs(amount), // Expenses are negative
            date: date,
            type: "expense",
            createdAt: date
        )
    }

    private func makeIncome(id: String? = nil, categoryId: String? = nil, amount: Double, daysAgo: Int = 0) -> FirestoreModels.TransactionModel {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return FirestoreModels.TransactionModel(
            id: id,
            userId: "u1",
            title: "Test Income",
            categoryId: categoryId,
            amount: abs(amount),
            date: date,
            type: "income",
            createdAt: date
        )
    }

    private func makeBudget(id: String = "budget1", category: String = "Food", totalAmount: Double = 500.0, frequency: String = "Monthly") -> FirestoreModels.CategoryBudget {
        // monthStartDate = start of this month in the *local* Calendar so the period
        // window computed by BudgetPeriodCalculator always covers today.
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let monthStart = calendar.date(from: components) ?? Date()
        let monthStartTimestamp = monthStart.timeIntervalSince1970

        // Use JSON decoding to correctly populate @DocumentID
        let json = """
        {
          "id": "\(id)",
          "category": "\(category)",
          "totalAmount": \(totalAmount),
          "icon": "fork.knife",
          "colorHex": "#FF0000",
          "frequency": "\(frequency)",
          "type": "expense",
          "userId": "u1",
          "monthStartDate": \(monthStartTimestamp),
          "createdAt": \(monthStartTimestamp)
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode(FirestoreModels.CategoryBudget.self, from: json))!
    }

    // MARK: - CategoryBudget.spentAmount

    @Test("spentAmount: no transactions returns zero")
    func test_spentAmount_noTransactions_returnsZero() {
        let budget = makeBudget()
        #expect(budget.spentAmount(transactions: []) == 0.0)
    }

    @Test("spentAmount: only matching expenses are counted")
    func test_spentAmount_matchingExpensesOnly() {
        let budget = makeBudget(id: "b1", category: "Food")
        let transactions = [
            makeExpense(id: "t1", categoryId: "b1", amount: 50.0),   // Matches
            makeExpense(id: "t2", categoryId: "b1", amount: 30.0),   // Matches
            makeExpense(id: "t3", categoryId: "b2", amount: 100.0),  // Different budget
        ]
        let spent = budget.spentAmount(transactions: transactions)
        #expect(spent == 80.0)
    }

    @Test("spentAmount: reimbursements (income) reduce net spent")
    func test_spentAmount_reimbursements_reduceNet() {
        let budget = makeBudget(id: "b1")
        // $100 expense, then $20 reimbursement in same category
        // net = $80 spent
        let transactions = [
            makeExpense(id: "t1", categoryId: "b1", amount: 100.0),
            makeIncome(id:  "t2", categoryId: "b1", amount: 20.0),
        ]
        let spent = budget.spentAmount(transactions: transactions)
        #expect(spent == 80.0)
    }

    @Test("spentAmount: full reimbursement results in zero net spent")
    func test_spentAmount_fullReimbursement_zeroNet() {
        let budget = makeBudget(id: "b1")
        let transactions = [
            makeExpense(id: "t1", categoryId: "b1", amount: 60.0),
            makeIncome(id:  "t2", categoryId: "b1", amount: 60.0),
        ]
        let spent = budget.spentAmount(transactions: transactions)
        #expect(spent == 0.0)
    }

    @Test("spentAmount: over-reimbursement cannot produce negative spent")
    func test_spentAmount_overReimbursement_notNegative() {
        let budget = makeBudget(id: "b1")
        let transactions = [
            makeExpense(id: "t1", categoryId: "b1", amount: 20.0),
            makeIncome(id:  "t2", categoryId: "b1", amount: 50.0),
        ]
        let spent = budget.spentAmount(transactions: transactions)
        // Net diff = 20 income > expense → spentAmount returns 0, not negative
        #expect(spent == 0.0)
    }

    // MARK: - CategoryBudget.remainingAmount

    @Test("remainingAmount: budget fully unspent equals totalAmount")
    func test_remainingAmount_unspent_equalsTotalAmount() {
        let budget = makeBudget(totalAmount: 300.0)
        let remaining = budget.remainingAmount(transactions: [])
        #expect(remaining == 300.0)
    }

    @Test("remainingAmount: correct subtraction using DecimalPrecision")
    func test_remainingAmount_subtractsSpentCorrectly() {
        let budget = makeBudget(id: "b1", totalAmount: 200.0)
        let transactions = [makeExpense(id: "t1", categoryId: "b1", amount: 75.50)]
        let remaining = budget.remainingAmount(transactions: transactions)
        #expect(remaining == 124.50)
    }

    @Test("remainingAmount: can go negative when overspent")
    func test_remainingAmount_overspent_isNegative() {
        let budget = makeBudget(id: "b1", totalAmount: 50.0)
        let transactions = [makeExpense(id: "t1", categoryId: "b1", amount: 80.0)]
        let remaining = budget.remainingAmount(transactions: transactions)
        #expect(remaining == -30.0)
    }

    // MARK: - CategoryBudget.grossSpentAmount

    @Test("grossSpentAmount: counts only expense transactions (not reimbursements)")
    func test_grossSpentAmount_expensesOnly() {
        let budget = makeBudget(id: "b1")
        let transactions = [
            makeExpense(id: "t1", categoryId: "b1", amount: 100.0),
            makeIncome(id:  "t2", categoryId: "b1", amount: 40.0), // Reimbursement
        ]
        let gross = budget.grossSpentAmount(transactions: transactions)
        #expect(gross == 100.0) // Reimbursement not deducted here
    }

    // MARK: - CategoryBudget.reimbursedAmount

    @Test("reimbursedAmount: sums income transactions in this category")
    func test_reimbursedAmount_sumsIncomeTransactions() {
        let budget = makeBudget(id: "b1")
        let transactions = [
            makeExpense(id: "t1", categoryId: "b1", amount: 50.0),
            makeIncome(id:  "t2", categoryId: "b1", amount: 15.0),
            makeIncome(id:  "t3", categoryId: "b1", amount: 10.0),
        ]
        let reimbursed = budget.reimbursedAmount(transactions: transactions)
        #expect(reimbursed == 25.0)
    }

    @Test("reimbursedAmount: zero when no income transactions")
    func test_reimbursedAmount_noIncome_isZero() {
        let budget = makeBudget(id: "b1")
        let transactions = [makeExpense(id: "t1", categoryId: "b1", amount: 90.0)]
        let reimbursed = budget.reimbursedAmount(transactions: transactions)
        #expect(reimbursed == 0.0)
    }

    // MARK: - BudgetPeriodCalculator

    @Test("Monthly window: anchor day 1, now mid-month — start is this month's 1st")
    func test_budgetPeriod_monthly_anchorDay1_startIsThisMonthFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Anchor: Jan 1
        var components = DateComponents(year: 2026, month: 1, day: 1)
        let anchor = calendar.date(from: components)!

        // Now: Jan 15
        components = DateComponents(year: 2026, month: 1, day: 15)
        let now = calendar.date(from: components)!

        let calculator = BudgetPeriodCalculator(calendar: calendar, anchor: anchor)
        let window = calculator.window(frequency: "Monthly", now: now)

        // Start should be Jan 1 2026
        let startDay   = calendar.component(.day,   from: window.start)
        let startMonth = calendar.component(.month, from: window.start)
        let startYear  = calendar.component(.year,  from: window.start)
        #expect(startDay == 1)
        #expect(startMonth == 1)
        #expect(startYear == 2026)
    }

    @Test("Monthly window: start is before now, end is one month later")
    func test_budgetPeriod_monthly_endIsOneMonthAfterStart() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var components = DateComponents(year: 2026, month: 3, day: 1)
        let anchor = calendar.date(from: components)!
        components = DateComponents(year: 2026, month: 3, day: 10)
        let now = calendar.date(from: components)!

        let calculator = BudgetPeriodCalculator(calendar: calendar, anchor: anchor)
        let window = calculator.window(frequency: "Monthly", now: now)

        let expectedEnd = calendar.date(byAdding: .month, value: 1, to: window.start)!
        #expect(window.end == expectedEnd)
    }

    @Test("Monthly window: now before anchor day rolls back to previous month")
    func test_budgetPeriod_monthly_nowBeforeAnchorDay_rollsBackToPreviousMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Anchor: 15th of the month
        var components = DateComponents(year: 2026, month: 1, day: 15)
        let anchor = calendar.date(from: components)!

        // Now: March 10 (before the 15th)
        components = DateComponents(year: 2026, month: 3, day: 10)
        let now = calendar.date(from: components)!

        let calculator = BudgetPeriodCalculator(calendar: calendar, anchor: anchor)
        let window = calculator.window(frequency: "Monthly", now: now)

        // Start should be Feb 15 (previous month's 15th), because March 15 is in the future
        let startDay   = calendar.component(.day,   from: window.start)
        let startMonth = calendar.component(.month, from: window.start)
        #expect(startDay == 15)
        #expect(startMonth == 2) // February
    }

    @Test("Weekly window: start is always the beginning of the current week")
    func test_budgetPeriod_weekly_startIsCurrentWeekStart() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Anchor: Monday Jan 5, 2026
        var components = DateComponents(year: 2026, month: 1, day: 5)
        let anchor = calendar.date(from: components)!

        // Now: Thursday Jan 8, 2026 (within same week)
        components = DateComponents(year: 2026, month: 1, day: 8)
        let now = calendar.date(from: components)!

        let calculator = BudgetPeriodCalculator(calendar: calendar, anchor: anchor)
        let window = calculator.window(frequency: "Weekly", now: now)

        // Window start must be <= now
        #expect(window.start <= now)
        // Window end must be 7 days after start
        let daysBetween = calendar.dateComponents([.day], from: window.start, to: window.end).day
        #expect(daysBetween == 7)
    }

    @Test("Yearly window: end is exactly 1 year after start")
    func test_budgetPeriod_yearly_endIsOneYearAfterStart() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var components = DateComponents(year: 2025, month: 6, day: 1)
        let anchor = calendar.date(from: components)!
        components = DateComponents(year: 2026, month: 3, day: 1)
        let now = calendar.date(from: components)!

        let calculator = BudgetPeriodCalculator(calendar: calendar, anchor: anchor)
        let window = calculator.window(frequency: "Yearly", now: now)

        let expectedEnd = calendar.date(byAdding: .year, value: 1, to: window.start)!
        #expect(window.end == expectedEnd)
        // Start must be before now
        #expect(window.start <= now)
    }

    // MARK: - WalletLogic.monthlyMultiplier

    @Test("monthlyMultiplier: Monthly frequency returns 1.0")
    func test_monthlyMultiplier_monthly_returnsOne() {
        let mult = WalletLogic.monthlyMultiplier(for: "Monthly")
        #expect(mult == 1.0)
    }

    @Test("monthlyMultiplier: Yearly frequency returns 1/12")
    func test_monthlyMultiplier_yearly_returnsTwelfth() {
        let mult = WalletLogic.monthlyMultiplier(for: "Yearly")
        #expect(abs(mult - (1.0 / 12.0)) < 0.0001)
    }

    @Test("monthlyMultiplier: Weekly frequency reflects days-in-month / 7")
    func test_monthlyMultiplier_weekly_basedOnDaysInMonth() {
        // Use a known reference month: January 2026 has 31 days
        let calendar = Calendar.current
        var components = DateComponents(year: 2026, month: 1, day: 15)
        let refDate = calendar.date(from: components)!

        let mult = WalletLogic.monthlyMultiplier(for: "Weekly", in: refDate)
        #expect(abs(mult - (31.0 / 7.0)) < 0.0001)
    }

    @Test("monthlyMultiplier: Bi-Weekly frequency is half the weekly multiplier")
    func test_monthlyMultiplier_biWeekly_isHalfWeekly() {
        var components = DateComponents(year: 2026, month: 1, day: 15)
        let refDate = Calendar.current.date(from: components)!

        let weekly    = WalletLogic.monthlyMultiplier(for: "Weekly",    in: refDate)
        let biWeekly  = WalletLogic.monthlyMultiplier(for: "Bi-Weekly", in: refDate)
        #expect(abs(biWeekly - weekly / 2.0) < 0.0001)
    }

    // MARK: - WalletLogic.calculateTotalBalance

    @Test("calculateTotalBalance: income adds to balance, expense subtracts")
    func test_calculateTotalBalance_incomeAddsExpenseSubtracts() {
        let balance = WalletLogic.calculateTotalBalance(
            initialBalance: 1000.0,
            aggregatedIncome: 500.0,
            aggregatedExpense: 200.0
        )
        // 1000 + 500 - 200 = 1300
        #expect(balance == 1300.0)
    }

    @Test("calculateTotalBalance: zero income and expense returns initial balance")
    func test_calculateTotalBalance_zeroFlows_returnsInitial() {
        let balance = WalletLogic.calculateTotalBalance(
            initialBalance: 750.0,
            aggregatedIncome: 0.0,
            aggregatedExpense: 0.0
        )
        #expect(balance == 750.0)
    }

    @Test("calculateTotalBalance: result can be negative (overspent)")
    func test_calculateTotalBalance_overspent_negative() {
        let balance = WalletLogic.calculateTotalBalance(
            initialBalance: 100.0,
            aggregatedIncome: 0.0,
            aggregatedExpense: 200.0
        )
        #expect(balance == -100.0)
    }

    // MARK: - WalletLogic.advanceDate

    @Test("advanceDate: Daily advances by 1 day")
    func test_advanceDate_daily_oneDayForward() {
        let calendar = Calendar.current
        var components = DateComponents(year: 2026, month: 3, day: 15)
        let start = calendar.date(from: components)!

        let result = WalletLogic.advanceDate(date: start, frequency: "Daily")
        let advanced = calendar.dateComponents([.day], from: start, to: result).day
        #expect(advanced == 1)
    }

    @Test("advanceDate: Weekly advances by 7 days")
    func test_advanceDate_weekly_sevenDaysForward() {
        let calendar = Calendar.current
        var components = DateComponents(year: 2026, month: 3, day: 1)
        let start = calendar.date(from: components)!

        let result = WalletLogic.advanceDate(date: start, frequency: "Weekly")
        let advanced = calendar.dateComponents([.day], from: start, to: result).day
        #expect(advanced == 7)
    }

    @Test("advanceDate: Bi-Weekly advances by 14 days")
    func test_advanceDate_biWeekly_fourteenDaysForward() {
        let calendar = Calendar.current
        var components = DateComponents(year: 2026, month: 3, day: 1)
        let start = calendar.date(from: components)!

        let result = WalletLogic.advanceDate(date: start, frequency: "Bi-Weekly")
        let advanced = calendar.dateComponents([.day], from: start, to: result).day
        #expect(advanced == 14)
    }

    @Test("advanceDate: Monthly advances by 1 month")
    func test_advanceDate_monthly_oneMonthForward() {
        let calendar = Calendar.current
        var components = DateComponents(year: 2026, month: 1, day: 31)
        let start = calendar.date(from: components)!

        let result = WalletLogic.advanceDate(date: start, frequency: "Monthly")
        let advanced = calendar.dateComponents([.month], from: start, to: result).month
        #expect(advanced == 1)
    }

    @Test("advanceDate: Yearly advances by 1 year")
    func test_advanceDate_yearly_oneYearForward() {
        let calendar = Calendar.current
        var components = DateComponents(year: 2026, month: 6, day: 15)
        let start = calendar.date(from: components)!

        let result = WalletLogic.advanceDate(date: start, frequency: "Yearly")
        let advanced = calendar.dateComponents([.year], from: start, to: result).year
        #expect(advanced == 1)
    }

    // MARK: - WalletLogic.calculateTotalExpense

    @Test("calculateTotalExpense: sums absolute values of all expense amounts")
    func test_calculateTotalExpense_sumsAbsoluteValues() {
        let transactions = [
            makeExpense(amount: 50.0),
            makeExpense(amount: 30.0),
            makeIncome(amount: 100.0), // Should be excluded
        ]
        let total = WalletLogic.calculateTotalExpense(transactions: transactions)
        #expect(total == 80.0)
    }

    @Test("calculateTotalExpense: empty list returns zero")
    func test_calculateTotalExpense_empty_returnsZero() {
        #expect(WalletLogic.calculateTotalExpense(transactions: []) == 0.0)
    }
}
