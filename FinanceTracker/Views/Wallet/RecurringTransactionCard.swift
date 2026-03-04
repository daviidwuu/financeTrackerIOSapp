import SwiftUI

struct RecurringTransactionCard: View {
    let transaction: FirestoreModels.RecurringTransaction
    let onDelete: () -> Void
    let onEdit: () -> Void
    @EnvironmentObject var budgetRepo: BudgetRepository
    
    /// Resolve icon from stored value, or look up from budget category
    private var resolvedIcon: String {
        if let icon = transaction.icon { return icon }
        if let budget = matchedBudget { return budget.icon }
        return "arrow.2.squarepath"
    }
    
    /// Resolve color from stored value, or look up from budget category
    private var resolvedColorHex: String {
        if let color = transaction.colorHex { return color }
        if let budget = matchedBudget { return budget.colorHex }
        return "#8E8E93"
    }
    
    /// Find the matching budget by categoryId or name
    private var matchedBudget: FirestoreModels.CategoryBudget? {
        if let catId = transaction.categoryId {
            return budgetRepo.budgets.first(where: { $0.id == catId })
        }
        return budgetRepo.budgets.first(where: { $0.category.lowercased() == transaction.name.lowercased() })
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: resolvedColorHex).opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: resolvedIcon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: resolvedColorHex))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Started: \(transaction.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(Int(transaction.amount))")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(transaction.frequency)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: resolvedColorHex).opacity(0.1))
                    .cornerRadius(AppRadius.small)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                HapticManager.shared.heavy()
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                HapticManager.shared.medium()
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}
