import SwiftUI

struct TransactionRow: View {
    let transaction: FirestoreModels.Transaction
    // Use shared repo from AppState
    var budgetRepo: BudgetRepository { appState.budgetRepo }
    @EnvironmentObject var appState: AppState
    
    // Dynamic lookup of category icon/color
    private var categoryIcon: String {
        if let budget = budgetRepo.budgets.first(where: { $0.category.lowercased() == (transaction.subtitle?.lowercased() ?? "") }) {
            return budget.icon
        }
        return "questionmark.circle.fill" // Fallback for "Others"
    }
    
    private var categoryColor: String {
        if let budget = budgetRepo.budgets.first(where: { $0.category.lowercased() == (transaction.subtitle?.lowercased() ?? "") }) {
            return budget.colorHex
        }
        return "#808080" // Gray for "Others"
    }
    
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: date)
        
        if calendar.isDateInToday(date) {
            return "Today at \(timeString)"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday at \(timeString)"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
            return "\(dateFormatter.string(from: date)) at \(timeString)"
        }
    }
    
    private func getSubtitleText() -> String? {
        let noteText = (transaction.note?.isEmpty == false) ? transaction.note : nil
        
        var amountText: String? = nil
        if let originalAmount = transaction.originalAmount,
           let currency = transaction.currencyCode {
            let amountString = String(format: "%.2f", abs(originalAmount))
            amountText = "(\(currency)$\(amountString))"
        }
        
        if let n = noteText, let a = amountText {
            return "\(n) \(a)"
        } else if let n = noteText {
            return n
        } else if let a = amountText {
            return a
        }
        return nil
    }

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            Circle()
                .fill(Color(hex: categoryColor).opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: categoryIcon)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: categoryColor))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // For Income, always show Category Name (subtitle) or "Income" as title
                Text(transaction.type == "income" ? (transaction.subtitle ?? "Income") : transaction.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.type == "income" ? Color(hex: transaction.colorHex) : .primary)
                
                // Subtitle logic
                if transaction.type != "income" {
                    if let subtitle = transaction.subtitle, !subtitle.isEmpty, subtitle != transaction.title {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Show note (or original title if it was hijackng description in legacy income)
                // Travel Mode: Show (Note) Currency$Amount
                if let subtitleText = getSubtitleText() {
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if transaction.type == "income" && transaction.title != (transaction.subtitle ?? "Income") {
                     // Fallback for legacy data where title was description
                    Text(transaction.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(formattedDate(transaction.date))
                    .font(.caption2)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            
            Spacer()
            
            Text(String(format: "%@$%.2f", transaction.amount > 0 ? "+" : "", abs(transaction.amount)))
                .font(.headline) // 17pt, slightly more prominent than body
                .fontWeight(.bold)
                .foregroundColor(transaction.amount > 0 ? Color(hex: "#34C759") : .primary) // Strict Guidelines Color
        }
        .padding(AppSpacing.element)
        .contentShape(Rectangle())
    }
}
