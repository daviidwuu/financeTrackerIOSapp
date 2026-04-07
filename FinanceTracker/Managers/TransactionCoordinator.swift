import Foundation
import SwiftUI

/// Handles all side-effects that follow a transaction save:
///  - Building the Firestore model from the UI form data
///  - Persisting via TransactionRepository
///  - Firing the post-save notification
///  - Evaluating budget thresholds and sending a budget warning if needed
///  - Refreshing the widget quick-log category list
///
/// Extracting this out of ContentView keeps the view a pure layout concern and
/// makes the save flow independently testable.
final class TransactionCoordinator {

    // MARK: - Dependencies (injected via init)

    private let transactionRepo: TransactionRepository
    private let budgetRepo: BudgetRepository
    private let currentUserIdProvider: () -> String

    @AppStorage("budgetAlertThreshold") private var budgetAlertThreshold: Double = 0.8

    init(
        transactionRepo: TransactionRepository,
        budgetRepo: BudgetRepository,
        currentUserIdProvider: @escaping () -> String
    ) {
        self.transactionRepo = transactionRepo
        self.budgetRepo = budgetRepo
        self.currentUserIdProvider = currentUserIdProvider
    }

    // MARK: - Save

    /// Validates, saves a transaction, and triggers all post-save side-effects.
    func addTransaction(_ transaction: TransactionFormData) {
        Task {
            do {
                let amount = Double(transaction.amount) ?? 0.0

                guard amount != 0 else {
                    DebugLogger.log("Ignoring transaction with zero amount")
                    return
                }

                let firestoreTransaction = transaction.firestoreModel(userId: currentUserIdProvider())

                try await transactionRepo.addTransaction(firestoreTransaction)

                // Post-save effects
                NotificationManager.shared.sendTransactionNotification(
                    amount: amount,
                    category: transaction.title,
                    type: transaction.type,
                    originalAmount: transaction.originalAmount,
                    currencyCode: transaction.currencyCode
                )

                checkBudgetStatus(for: transaction.title, amount: amount)
                refreshWidgetCategories()

            } catch {
                DebugLogger.log("Failed to add transaction: \(error)")
            }
        }
    }

    // MARK: - Budget Check

    private func checkBudgetStatus(for category: String, amount: Double) {
        guard amount < 0 else { return }

        guard let budget = budgetRepo.budgets.first(where: { $0.category == category }) else { return }

        let spent = budget.spentAmount(transactions: transactionRepo.allTransactions)
        let totalLimit = budget.totalAmount

        guard totalLimit > 0 else { return }

        let percent = (spent / totalLimit) * 100
        guard !percent.isNaN && !percent.isInfinite else { return }

        let percentUsed = Int(percent)
        let threshold = Int(budgetAlertThreshold * 100)

        if percentUsed >= threshold {
            let remaining = totalLimit - spent
            NotificationManager.shared.sendBudgetWarning(
                category: category,
                percentUsed: percentUsed,
                remaining: remaining
            )
        }
    }

    // MARK: - Widget Refresh

    private func refreshWidgetCategories() {
        let topBudgets = budgetRepo.budgets
            .filter { $0.category.lowercased() != "income" }
            .prefix(4)
            .map {
                WidgetDataManager.WidgetCategory(
                    name: $0.category,
                    icon: $0.icon,
                    colorHex: $0.colorHex
                )
            }
        WidgetDataManager.shared.saveQuickLogCategories(Array(topBudgets))
    }
}
