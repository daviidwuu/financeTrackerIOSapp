import Foundation

extension FirestoreModels.TransactionModel {
    var isReimbursementIncome: Bool {
        guard type.lowercased() == "income" else { return false }
        guard let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let normalized = subtitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized != "income" && normalized != "salary"
    }
}
