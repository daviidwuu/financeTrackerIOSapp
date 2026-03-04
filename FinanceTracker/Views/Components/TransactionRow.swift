import SwiftUI

struct TransactionRow: View {
    let transaction: FirestoreModels.TransactionModel
    // Use shared repo from AppState
    @EnvironmentObject var budgetRepo: BudgetRepository
    @EnvironmentObject var appState: AppState
    
    // Dynamic lookup of category icon/color
    private var resolvedCategory: FirestoreModels.CategoryBudget? {
        if let categoryId = transaction.categoryId {
            return budgetRepo.getCategory(for: categoryId)
        }
        return nil // No fallback to subtitle anymore
    }

    private var categoryIcon: String {
        return resolvedCategory?.icon ?? "questionmark.circle.fill"
    }
    
    private var categoryColor: String {
        return resolvedCategory?.colorHex ?? "#808080"
    }

    private var categoryName: String {
        return resolvedCategory?.category ?? transaction.title
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
    

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.element) {
            if budgetRepo.isLoading && budgetRepo.budgets.isEmpty {
                // Show a blank placeholder while loading to prevent "questionmark" flash
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 48, height: 48)
            } else {
                Circle()
                    .fill(Color(hex: categoryColor).opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: categoryIcon)
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: categoryColor))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // NEW: Show Category as Title
                Text(categoryName)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.amount > 0 ? Color(hex: "#34C759") : .primary)
                
                // NEW: Show Note or Merchant (Title) as Subtitle
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if transaction.title != categoryName {
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
            
            // Split Indicator (Left of Amount)
            if let splits = transaction.splits, !splits.isEmpty {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%@$%.2f", transaction.amount > 0 ? "+" : "", abs(transaction.amount)))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(transaction.amount > 0 ? Color(hex: "#34C759") : .primary)
                
                if let originalAmount = transaction.originalAmount, let currencyCode = transaction.currencyCode {
                    Text(String(format: "%@%@ %.2f", transaction.amount > 0 ? "+" : "", currencyCode, abs(originalAmount)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(AppSpacing.element)
        .contentShape(Rectangle())
    }
}
