import SwiftUI

struct WalletRecurringSection: View {
    @EnvironmentObject var recurringRepo: RecurringTransactionRepository
    let hiddenItemIds: Set<String>
    var onAdd: () -> Void
    var onEdit: (FirestoreModels.RecurringTransaction) -> Void
    var onDelete: (FirestoreModels.RecurringTransaction) -> Void
    var onView: (FirestoreModels.RecurringTransaction) -> Void

    var body: some View {
        Section(header:
            HStack {
                Text("Recurring").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                Spacer()
                Button(action: { HapticManager.shared.light(); onAdd() }) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.primary)
                }
            }
            .textCase(nil)
            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
        ) {
            if recurringRepo.recurringTransactions.isEmpty {
                EmptyStateView(
                    icon: "arrow.2.squarepath",
                    title: "No Recurring",
                    message: "Add subscriptions or bills to track your future spending.",
                    actionTitle: "Add Recurring",
                    action: onAdd
                )
                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(recurringRepo.recurringTransactions.filter { !hiddenItemIds.contains($0.id ?? "") }) { recurring in
                    Button(action: { HapticManager.shared.light(); onView(recurring) }) {
                        RecurringTransactionCard(
                            transaction: recurring,
                            onDelete: { onDelete(recurring) },
                            onEdit: { onEdit(recurring) }
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listRowBackground(Color.clear)
    }
}
