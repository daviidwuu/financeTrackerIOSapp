import Foundation

extension FirestoreModels.TransactionModel {
    /// FIX #6: Determines if this income transaction is a reimbursement (not real salary/income).
    /// Uses the category's `type` field first (reliable), then falls back to name matching for legacy data.
    func isReimbursementIncome(categories: [FirestoreModels.CategoryBudget]) -> Bool {
        guard type.lowercased() == "income" else { return false }

        // Must have a categoryId to be considered a reimbursement
        guard let categoryId = self.categoryId else {
            return false // No category → treat as standard income, not a reimbursement
        }

        if let matchedCategory = categories.first(where: { $0.id == categoryId }) {
            // Primary check: use the category's type field (reliable, language-independent)
            if let categoryType = matchedCategory.type?.lowercased() {
                if categoryType == "income" {
                    return false // It's an income-type category → standard income
                }
                // Category is expense-type but transaction is income → reimbursement
                return true
            }

            // Fallback: name-based check for legacy data without type field
            let normalized = matchedCategory.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "income" || normalized == "salary" {
                return false // It's standard income/salary
            }
        } else {
            return false // categoryId doesn't match any budget → treat as standard income
        }

        // Income mapped to a non-income category → reimbursement
        return true
    }
}
