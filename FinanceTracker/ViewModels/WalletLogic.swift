import Foundation

struct WalletLogic {
    
    // MARK: - Income & Balance
    
    static func calculateMonthlyIncome(recurringTransactions: [FirestoreModels.RecurringTransaction]) -> Double {
        recurringTransactions
            .filter { $0.type == "income" }
            .reduce(0) { sum, transaction in
                switch transaction.frequency {
                case "Weekly": return sum + (transaction.amount * 52.0 / 12.0)
                case "Bi-Weekly": return sum + (transaction.amount * 26.0 / 12.0)
                case "Yearly": return sum + (transaction.amount / 12.0)
                default: return sum + transaction.amount
                }
            }
    }
    
    static func calculateTotalBalance(initialBalance: Double, transactions: [FirestoreModels.TransactionModel]) -> Double {
        let allTimeNet = transactions.reduce(0) { $0 + $1.amount }
        return initialBalance + allTimeNet
    }
    
    static func calculateTotalBudget(budgets: [FirestoreModels.CategoryBudget]) -> Double {
        budgets.filter { $0.type != "income" }.reduce(0) { sum, budget in
            var monthlyAmount = budget.totalAmount
            switch budget.frequency {
            case "Weekly": monthlyAmount = budget.totalAmount * 52.0 / 12.0
            case "Bi-Weekly": monthlyAmount = budget.totalAmount * 26.0 / 12.0
            case "Yearly": monthlyAmount = budget.totalAmount / 12.0
            default: break
            }
            return sum + monthlyAmount
        }
    }
    
    static func calculateIncomeLeft(monthlyIncome: Double, transactions: [FirestoreModels.TransactionModel]) -> Double {
        let calendar = Calendar.current
        let currentMonthTransactions = transactions.filter { transaction in
            guard transaction.type == "expense" else { return false }
            return calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
        let totalSpent = currentMonthTransactions.reduce(0) { $0 + $1.amount } // amount is negative
        return monthlyIncome + totalSpent
    }
    
    static func calculateCurrentMonthIncome(transactions: [FirestoreModels.TransactionModel]) -> Double {
        let calendar = Calendar.current
        let currentMonthTransactions = transactions.filter { transaction in
            guard transaction.type == "income" else { return false }
            return calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
        return currentMonthTransactions.reduce(0) { $0 + $1.amount }
    }
    
    static func calculateTotalExpense(transactions: [FirestoreModels.TransactionModel]) -> Double {
        let allExpenses = transactions.filter { $0.type == "expense" }
        return abs(allExpenses.reduce(0) { $0 + $1.amount })
    }
    
    static func calculateNetCashFlow(transactions: [FirestoreModels.TransactionModel]) -> Double {
        let calendar = Calendar.current
        let currentMonthTransactions = transactions.filter { transaction in
            return calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
        return currentMonthTransactions.reduce(0) { $0 + $1.amount }
    }
    
    static func calculateNetSpent(transactions: [FirestoreModels.TransactionModel]) -> Double {
        let calendar = Calendar.current
        let currentMonthTransactions = transactions.filter { transaction in
            return calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
        
        // 1. Calculate pure expenses (Type == expense)
        let expenses = currentMonthTransactions
            .filter { $0.type == "expense" }
            .reduce(0) { $0 + abs($1.amount) }
        
        // 2. Calculate reimbursements (Type == income BUT not Salary/Income category)
        let reimbursements = currentMonthTransactions
            .filter {
                $0.type == "income" &&
                ($0.subtitle != "Income" && $0.subtitle != "Salary")
            }
            .reduce(0) { $0 + abs($1.amount) }
            
        return max(0, expenses - reimbursements)
    }
    
    // MARK: - Savings Pool Logic
    
    static func calculateAllTimeSavingsPool(
        signupDate: Date?,
        transactions: [FirestoreModels.TransactionModel],
        totalBudget: Double,
        monthlyIncome: Double
    ) -> Double {
        // Find signup date: AppState or fallback to first transaction
        let startParamsDate: Date
        if let appDate = signupDate {
            startParamsDate = appDate
        } else if let firstTransaction = transactions.last?.date {
            startParamsDate = firstTransaction
        } else {
            return 0
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var current = calendar.startOfDay(for: startParamsDate)
        
        var totalPool = 0.0
        
        // Sum up the surplus for every day since signup
        while current <= today {
            totalPool += calculateSurplus(for: current, transactions: transactions, totalBudget: totalBudget, monthlyIncome: monthlyIncome)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDay
        }
        
        return max(0, totalPool)
    }
    
    static func calculateSurplus(
        for date: Date,
        transactions: [FirestoreModels.TransactionModel],
        totalBudget: Double,
        monthlyIncome: Double
    ) -> Double {
        let calendar = Calendar.current
        
        // 1. Get the number of days in this specific month
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return 0 }
        let daysInMonthCount = Double(range.count)
        
        // 2. Determine the Daily Allowance (The "Grind" Budget)
        let dailyAllowance = totalBudget / daysInMonthCount
        
        // 3. Calculate "Manual" Flow for this specific day
        // Optimization: This filter might be slow if transactions list is huge.
        // Ideally, transactions should be indexed by date, but for now we keep logic same.
        let dailyTransactions = transactions.filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }
        
        let dailySpent = dailyTransactions
            .filter { $0.type == "expense" }
            .reduce(0) { $0 + abs($1.amount) }
            
        let dailyManualIncome = dailyTransactions
            .filter { transaction in
                guard transaction.type == "income" else { return false }
                // Exclude auto-generated recurring income to prevent double counting with "Vault" logic
                if transaction.source == "recurring" { return false }
                if let note = transaction.note, note.contains("Recurring:") { return false }
                return true
            }
            .reduce(0) { $0 + $1.amount }
            
        // 4. Base Surplus (The Simulation Result)
        var surplus = dailyAllowance - dailySpent + dailyManualIncome
        
        // 5. The Reconciliation (The Vault Reveal - Only on the last day of a month)
        if let monthInterval = calendar.dateInterval(of: .month, for: date),
           let endOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
           calendar.isDate(date, inSameDayAs: endOfMonth) {
            
            // Add the unallocated Recurring Income (The Vault)
            let vaultSavings = monthlyIncome - totalBudget
            surplus += vaultSavings
        }
        
        return surplus
    }
    
    static func calculateGoalAllocation(for index: Int, in goals: [FirestoreModels.SavingGoal], pool: Double) -> Double {
        var remainingPool = pool
        for i in 0..<goals.count {
            let goal = goals[i]
            let needed = goal.targetAmount
            let allocation = min(remainingPool, needed)
            let clamped = max(0, min(allocation, goal.targetAmount - goal.currentAmount))
            
            if i == index {
                return clamped
            }
            
            remainingPool -= clamped
            if remainingPool <= 0 { break }
        }
        return 0
    }
}
