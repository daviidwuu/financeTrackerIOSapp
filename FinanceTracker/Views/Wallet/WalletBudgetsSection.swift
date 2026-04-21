import SwiftUI

struct WalletBudgetsSection: View {
    @EnvironmentObject var budgetRepo: BudgetRepository
    @EnvironmentObject var transactionRepo: TransactionRepository
    let hiddenItemIds: Set<String>
    var onAdd: () -> Void
    var onEdit: (FirestoreModels.CategoryBudget) -> Void
    var onDelete: (FirestoreModels.CategoryBudget) -> Void

    var body: some View {
        Section(header:
            HStack {
                Text("Budgets").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                Spacer()
                Button(action: { HapticManager.shared.light(); onAdd() }) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.primary)
                }
            }
            .textCase(nil)
            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
        ) {
            if budgetRepo.budgets.isEmpty {
                EmptyStateView(
                    icon: "chart.pie.fill",
                    title: "No Budgets",
                    message: "Organize your spending with category budgets.",
                    actionTitle: "Add Budget",
                    action: onAdd
                )
                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(budgetRepo.budgets.filter { $0.category != "Income" && !hiddenItemIds.contains($0.id ?? "") }) { budget in
                    BudgetRow(budget: budget, allTransactions: transactionRepo.allTransactions)
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { onDelete(budget) } label: {
                                Label("Delete", systemImage: "trash")
                            }.tint(Color.functionalError)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { HapticManager.shared.medium(); onEdit(budget) } label: {
                                Label("Edit", systemImage: "pencil")
                            }.tint(.blue)
                        }
                }
            }
        }
        .listRowBackground(Color.clear)
    }
}

private struct BudgetRow: View {
    let budget: FirestoreModels.CategoryBudget
    let allTransactions: [FirestoreModels.TransactionModel]

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            ZStack {
                Circle().fill(Color(hex: budget.colorHex).opacity(0.15)).frame(width: AppSize.avatarList, height: AppSize.avatarList)
                Image(systemName: budget.icon).font(.system(size: 20)).foregroundColor(Color(hex: budget.colorHex))
            }
            Text(budget.category).font(.headline)
            Spacer()
            if budget.totalAmount == 0 {
                let spent = abs(budget.remainingAmount(transactions: allTransactions))
                Text("$\(Int(spent)) spent").font(.system(.subheadline, design: .rounded)).foregroundColor(.secondary)
            } else {
                Text("$\(Int(budget.remainingAmount(transactions: allTransactions))) left")
                    .font(.system(.subheadline, design: .rounded)).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }
}
