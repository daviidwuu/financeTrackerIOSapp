import Foundation
import SwiftUI
import Combine

@MainActor
final class WalletViewModel: ObservableObject {

    // MARK: - Published State

    @Published var savingsPool: Double = 0
    @Published var breakdownMonth: Date = Date()

    // MARK: - Computed Derived Values (via WalletLogic)

    func totalBalance(initialBalance: Double, aggregatedIncome: Double, aggregatedExpense: Double) -> Double {
        WalletLogic.calculateTotalBalance(
            initialBalance: initialBalance,
            aggregatedIncome: aggregatedIncome,
            aggregatedExpense: aggregatedExpense
        )
    }

    func monthlyIncome(recurringTransactions: [FirestoreModels.RecurringTransaction]) -> Double {
        WalletLogic.calculateMonthlyIncome(recurringTransactions: recurringTransactions)
    }

    func totalBudget(budgets: [FirestoreModels.CategoryBudget]) -> Double {
        WalletLogic.calculateTotalBudget(budgets: budgets)
    }

    func breakdownTransactions(allTransactions: [FirestoreModels.TransactionModel]) -> [FirestoreModels.TransactionModel] {
        allTransactions.filter {
            Calendar.current.isDate($0.date, equalTo: breakdownMonth, toGranularity: .month)
        }
    }

    func canGoToNextMonth(from date: Date) -> Bool {
        let calendar = Calendar.current
        let current = calendar.dateComponents([.year, .month], from: Date())
        let target = calendar.dateComponents([.year, .month], from: date)
        guard let cy = current.year, let cm = current.month, let ty = target.year, let tm = target.month else { return false }
        return ty < cy || (ty == cy && tm < cm)
    }

    func netWorthTrendPoints(allTransactions: [FirestoreModels.TransactionModel], initialBalance: Double) -> [Double] {
        guard !allTransactions.isEmpty else { return [0, 1] }
        let calendar = Calendar.current
        let today = Date()
        var points: [Double] = []
        for i in (0..<6).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: today),
                  let nextMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from:
                      calendar.date(byAdding: .month, value: 1, to: monthDate)!)) else { continue }
            var balance = initialBalance
            for tx in allTransactions where tx.date < nextMonthStart {
                balance += (tx.type == "income" || tx.type == "settlement") ? abs(tx.amount) : -abs(tx.amount)
            }
            points.append(balance)
        }
        if let first = points.first, points.allSatisfy({ $0 == first }) { return [first, first + 1] }
        return points
    }

    func goalAllocation(for index: Int, in goals: [FirestoreModels.SavingGoal]) -> Double {
        WalletLogic.calculateGoalAllocation(for: index, in: goals, pool: savingsPool)
    }

    // MARK: - Savings Pool

    func refreshSavingsPool(signupDate: Date?, allTransactions: [FirestoreModels.TransactionModel], budgets: [FirestoreModels.CategoryBudget]) {
        savingsPool = WalletLogic.calculateAllTimeSavingsPool(
            signupDate: signupDate,
            transactions: allTransactions,
            totalBudget: WalletLogic.calculateTotalBudget(budgets: budgets),
            categories: budgets
        )
    }

    // MARK: - Saving Goals

    func addSavingGoal(_ formData: SavingGoalFormData, userId: String, repo: SavingGoalRepository, errorState: ErrorState) {
        Task {
            do {
                let goal = FirestoreModels.SavingGoal(
                    name: formData.name,
                    targetAmount: formData.targetAmount,
                    currentAmount: formData.currentAmount,
                    targetDate: formData.targetDate,
                    icon: formData.icon,
                    colorHex: formData.color.toHex() ?? "#000000",
                    userId: userId
                )
                try await repo.addSavingGoal(goal)
            } catch { errorState.show("Failed to save goal") }
        }
    }

    func updateSavingGoal(_ entity: FirestoreModels.SavingGoal, with formData: SavingGoalFormData, repo: SavingGoalRepository, errorState: ErrorState) {
        var updated = entity
        updated.name = formData.name
        updated.targetAmount = formData.targetAmount
        updated.currentAmount = formData.currentAmount
        updated.targetDate = formData.targetDate
        updated.icon = formData.icon
        updated.colorHex = formData.color.toHex() ?? "#000000"
        Task {
            do { try await repo.updateSavingGoal(updated) }
            catch { errorState.show("Failed to update goal") }
        }
    }

    // MARK: - Recurring Transactions

    func addRecurringTransaction(_ formData: RecurringTransactionFormData, userId: String, repo: RecurringTransactionRepository, errorState: ErrorState) {
        Task {
            do {
                let tx = FirestoreModels.RecurringTransaction(
                    name: formData.name,
                    amount: formData.amount,
                    frequency: formData.frequency,
                    startDate: formData.startDate,
                    categoryId: formData.categoryId,
                    icon: formData.icon,
                    colorHex: formData.color.toHex() ?? "#000000",
                    note: formData.notes,
                    type: formData.type,
                    userId: userId
                )
                try await repo.addRecurringTransaction(tx)
            } catch { errorState.show("Failed to save recurring transaction") }
        }
    }

    func updateRecurringTransaction(_ entity: FirestoreModels.RecurringTransaction, with formData: RecurringTransactionFormData, repo: RecurringTransactionRepository, errorState: ErrorState) {
        var updated = entity
        updated.name = formData.name
        updated.amount = formData.amount
        updated.frequency = formData.frequency
        updated.icon = formData.icon
        updated.colorHex = formData.color.toHex() ?? "#000000"
        updated.note = formData.notes
        updated.startDate = formData.startDate
        updated.type = formData.type
        Task {
            do { try await repo.updateRecurringTransaction(updated) }
            catch { errorState.show("Failed to update recurring transaction") }
        }
    }

    // MARK: - Budgets

    func addBudget(_ formData: BudgetFormData, userId: String, repo: BudgetRepository, errorState: ErrorState) {
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        Task {
            do {
                let budget = FirestoreModels.CategoryBudget(
                    category: formData.category,
                    totalAmount: formData.totalAmount,
                    icon: formData.icon,
                    colorHex: formData.color.toHex() ?? "#000000",
                    frequency: formData.frequency,
                    type: formData.type,
                    userId: userId,
                    monthStartDate: startOfMonth
                )
                try await repo.addBudget(budget)
            } catch { errorState.show("Failed to save budget") }
        }
    }

    func updateBudget(_ entity: FirestoreModels.CategoryBudget, with formData: BudgetFormData, repo: BudgetRepository, errorState: ErrorState) {
        var updated = entity
        updated.category = formData.category
        updated.totalAmount = formData.totalAmount
        updated.icon = formData.icon
        updated.colorHex = formData.color.toHex() ?? "#000000"
        updated.frequency = formData.frequency
        updated.type = formData.type
        Task {
            do { try await repo.updateBudget(updated) }
            catch { errorState.show("Failed to update budget") }
        }
    }
}
