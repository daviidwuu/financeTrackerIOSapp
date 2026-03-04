import Foundation

struct WalletLogic {

    // MARK: - Calendar-Accurate Frequency Helpers

    /// FIX #3: Count how many times a recurring event with the given frequency
    /// actually occurs in the month containing `referenceDate`.
    /// This replaces the inaccurate 52/12 and 26/12 yearly-average multipliers.
    static func monthlyMultiplier(for frequency: String, in referenceDate: Date = Date()) -> Double {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: referenceDate) else {
            return 1.0
        }
        let daysInMonth = Double(range.count)

        switch frequency {
        case "Weekly":       return daysInMonth / 7.0     // ~4.0–4.43
        case "Bi-Weekly":    return daysInMonth / 14.0    // ~2.0–2.21
        case "Yearly":       return 1.0 / 12.0
        default:             return 1.0 // Monthly
        }
    }

    // MARK: - Income & Balance

    static func calculateMonthlyIncome(recurringTransactions: [FirestoreModels.RecurringTransaction]) -> Double {
        let amounts: [Double] = recurringTransactions
            .filter { $0.type == "income" }
            .map { transaction in
                // FIX #3: Use calendar-accurate multiplier instead of yearly averages
                DecimalPrecision.multiply(transaction.amount, monthlyMultiplier(for: transaction.frequency))
            }
        return DecimalPrecision.sum(amounts)
    }

    static func calculateTotalBalance(initialBalance: Double, aggregatedIncome: Double, aggregatedExpense: Double) -> Double {
        return DecimalPrecision.subtract(initialBalance + aggregatedIncome, aggregatedExpense)
    }

    static func calculateTotalBudget(budgets: [FirestoreModels.CategoryBudget]) -> Double {
        let amounts: [Double] = budgets.filter { $0.type != "income" }.map { budget in
            // FIX #3: Use calendar-accurate multiplier instead of yearly averages
            DecimalPrecision.multiply(budget.totalAmount, monthlyMultiplier(for: budget.frequency))
        }
        return DecimalPrecision.sum(amounts)
    }

    static func calculateIncomeLeft(monthlyIncome: Double, transactions: [FirestoreModels.TransactionModel]) -> Double {
        let calendar = Calendar.current
        let expenseAmounts = transactions
            .filter { $0.type == "expense" && calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .map { $0.amount } // negative
        let totalSpent = DecimalPrecision.sum(expenseAmounts)
        return DecimalPrecision.round(monthlyIncome + totalSpent)
    }

    static func calculateCurrentMonthIncome(transactions: [FirestoreModels.TransactionModel]) -> Double {
        let calendar = Calendar.current
        let incomeAmounts = transactions
            .filter { $0.type == "income" && calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .map { $0.amount }
        return DecimalPrecision.sum(incomeAmounts)
    }

    static func calculateTotalExpense(transactions: [FirestoreModels.TransactionModel]) -> Double {
        let expenseAmounts = transactions
            .filter { $0.type == "expense" }
            .map { $0.amount }
        return abs(DecimalPrecision.sum(expenseAmounts))
    }

    static func calculateCurrentMonthExpense(transactions: [FirestoreModels.TransactionModel]) -> Double {
        let calendar = Calendar.current
        let expenseAmounts = transactions
            .filter { $0.type == "expense" && calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .map { $0.amount }
        return abs(DecimalPrecision.sum(expenseAmounts))
    }

    static func calculateNetCashFlow(transactions: [FirestoreModels.TransactionModel]) -> Double {
        let calendar = Calendar.current
        let amounts = transactions
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .map { $0.amount }
        return DecimalPrecision.sum(amounts)
    }

    static func calculateNetSpent(transactions: [FirestoreModels.TransactionModel], categories: [FirestoreModels.CategoryBudget]) -> Double {
        // Transactions are already month-filtered by the Firestore listener (currentMonthTransactions),
        // so no redundant Calendar filtering is needed here.

        // 1. Calculate pure expenses (Type == expense)
        let expenses = DecimalPrecision.sum(
            transactions.filter { $0.type == "expense" }.map { abs($0.amount) }
        )

        // 2. Calculate reimbursements using the robust extension
        let reimbursements = DecimalPrecision.sum(
            transactions.filter { $0.isReimbursementIncome(categories: categories) }.map { abs($0.amount) }
        )

        return max(0, DecimalPrecision.subtract(expenses, reimbursements))
    }

    // MARK: - Savings Pool Logic

    static func calculateAllTimeSavingsPool(
        signupDate: Date?,
        transactions: [FirestoreModels.TransactionModel],
        totalBudget: Double,
        categories: [FirestoreModels.CategoryBudget]
    ) -> Double {
        // Find signup date: AppState or fallback to first transaction
        let startParamsDate: Date
        if let appDate = signupDate {
            startParamsDate = appDate
        } else if let savedDate = UserDefaults.standard.object(forKey: "userSignupDate") as? Date {
            // FIX #20: Use persisted signup date instead of transactions.last which depends on sort order
            startParamsDate = savedDate
        } else if let firstTransaction = transactions.min(by: { $0.date < $1.date })?.date {
            // Final fallback: earliest transaction date (not .last which is sort-order dependent)
            startParamsDate = firstTransaction
        } else {
            return 0
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var current = calendar.startOfDay(for: startParamsDate)

        // FIX #1: Use Decimal accumulation for the day-by-day loop to avoid floating-point drift.
        // Include today (current <= today) so the pool matches the sum of all monthly savings.
        var totalPool = Decimal.zero

        while current <= today {
            totalPool += Decimal(calculateSurplus(for: current, transactions: transactions, totalBudget: totalBudget, categories: categories))
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDay
        }

        let result = NSDecimalNumber(decimal: totalPool).doubleValue
        return max(0, DecimalPrecision.round(result))
    }

    static func calculateSurplus(
        for date: Date,
        transactions: [FirestoreModels.TransactionModel],
        totalBudget: Double,
        categories: [FirestoreModels.CategoryBudget]
    ) -> Double {
        let calendar = Calendar.current

        guard let range = calendar.range(of: .day, in: .month, for: date) else { return 0 }
        let daysInMonthCount = Double(range.count)

        let dailyAllowance = DecimalPrecision.divide(totalBudget, daysInMonthCount)

        let dailyTransactions = transactions.filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }

        let dailySpent = DecimalPrecision.sum(
            dailyTransactions.filter { $0.type == "expense" }.map { abs($0.amount) }
        )

        let dailyReimbursements = DecimalPrecision.sum(
            dailyTransactions.filter { $0.isReimbursementIncome(categories: categories) }.map { $0.amount }
        )

        return DecimalPrecision.round(dailyAllowance - dailySpent + dailyReimbursements)
    }

    static func calculateGoalAllocation(for index: Int, in goals: [FirestoreModels.SavingGoal], pool: Double) -> Double {
        var remainingPool = Decimal(max(0, pool))
        for i in 0..<goals.count {
            let goal = goals[i]
            let allocation = min(remainingPool, Decimal(goal.targetAmount))

            if i == index {
                return NSDecimalNumber(decimal: allocation).doubleValue
            }

            remainingPool -= allocation
            if remainingPool <= 0 { break }
        }

        return 0
    }

    // MARK: - Recurring Transactions

    static func calculateMissedOccurrences(
        recurring: FirestoreModels.RecurringTransaction,
        loggedTransactions: [FirestoreModels.TransactionModel]
    ) -> [Date] {
        let calendar = Calendar.current

        // 1. Get today's start in local timezone
        let today = calendar.startOfDay(for: Date())

        // 2. Adjust startDate for Timezone (UTC to Local)
        // Firebase often stores midnight UTC, which can fall on the wrong calendar day locally.
        // We get the components in the local timezone and reconstruct midnight locally.
        let localComponents = calendar.dateComponents([.year, .month, .day], from: recurring.startDate)
        let localStartDate = calendar.date(from: localComponents) ?? recurring.startDate

        // 3. Start checking from the local start date
        var currentCheckDate = calendar.startOfDay(for: localStartDate)
        var missedDates: [Date] = []

        // 4. Loop strictly before today. Today hasn't ended yet, so we shouldn't flag it as missed.
        while currentCheckDate < today {
            let alreadyLogged = loggedTransactions.contains { tx in
                let txLocalComponents = calendar.dateComponents([.year, .month, .day], from: tx.date)
                let txLocalDate = calendar.date(from: txLocalComponents) ?? tx.date
                let matchesDate = calendar.isDate(txLocalDate, inSameDayAs: currentCheckDate)
                guard matchesDate else { return false }

                let matchesTitle = tx.title.lowercased() == recurring.name.lowercased()
                guard matchesTitle else { return false }

                let amountDiff = abs(abs(tx.amount) - abs(recurring.amount))
                let matchesAmount = amountDiff < 0.01

                return matchesAmount
            }

            if !alreadyLogged {
                missedDates.append(currentCheckDate)
            }

            currentCheckDate = WalletLogic.advanceDate(date: currentCheckDate, frequency: recurring.frequency)
        }

        return missedDates.sorted(by: { $0 > $1 })
    }

    // Helper to advance date by frequency matching the Cloud Function behavior
    static func advanceDate(date: Date, frequency: String, multiplier: Int = 1) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()

        switch frequency {
        case "Daily": components.day = 1 * multiplier
        case "Weekly": components.day = 7 * multiplier
        case "Bi-Weekly": components.day = 14 * multiplier
        case "Yearly": components.year = 1 * multiplier
        default: components.month = 1 * multiplier // Monthly
        }

        return calendar.date(byAdding: components, to: date) ?? date
    }
}
