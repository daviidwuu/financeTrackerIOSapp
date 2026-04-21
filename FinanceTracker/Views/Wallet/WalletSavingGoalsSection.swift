import SwiftUI

struct WalletSavingGoalsSection: View {
    @EnvironmentObject var savingGoalRepo: SavingGoalRepository
    @EnvironmentObject var transactionRepo: TransactionRepository
    let hiddenItemIds: Set<String>
    let goalAllocation: (Int, [FirestoreModels.SavingGoal]) -> Double
    var onAdd: () -> Void
    var onEdit: (FirestoreModels.SavingGoal) -> Void
    var onDelete: (FirestoreModels.SavingGoal) -> Void
    var onMove: (IndexSet, Int) -> Void

    var body: some View {
        Section(header:
            HStack {
                Text("Saving Goals").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                Spacer()
                Button(action: { HapticManager.shared.light(); onAdd() }) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.primary)
                }
            }
            .textCase(nil)
            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
        ) {
            if savingGoalRepo.savingGoals.isEmpty {
                EmptyStateView(
                    icon: "target",
                    title: "No Goals",
                    message: "Set a saving goal to start tracking your progress!",
                    actionTitle: "Add Goal",
                    action: onAdd
                )
                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                let visibleGoals = savingGoalRepo.savingGoals.filter { !hiddenItemIds.contains($0.id ?? "") }
                let allocations = visibleGoals.enumerated().map { (i, goal) in
                    (goal: goal, amount: goalAllocation(i, visibleGoals))
                }

                ForEach(allocations, id: \.goal.id) { item in
                    SavingGoalRow(goal: item.goal, currentAmount: item.amount)
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { onDelete(item.goal) } label: {
                                Label("Delete", systemImage: "trash")
                            }.tint(Color.functionalError)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { HapticManager.shared.medium(); onEdit(item.goal) } label: {
                                Label("Edit", systemImage: "pencil")
                            }.tint(.blue)
                        }
                }
                .onMove(perform: onMove)
            }
        }
        .listRowBackground(Color.clear)
    }
}

private struct SavingGoalRow: View {
    let goal: FirestoreModels.SavingGoal
    let currentAmount: Double

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            ZStack {
                Circle().fill(Color(hex: goal.colorHex).opacity(0.15)).frame(width: AppSize.avatarList, height: AppSize.avatarList)
                Image(systemName: goal.icon).font(.system(size: 20)).foregroundColor(Color(hex: goal.colorHex))
            }
            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(goal.name).font(.headline)
                Text("$\(Int(currentAmount)) / $\(Int(goal.targetAmount))")
                    .font(.system(.subheadline, design: .rounded)).foregroundColor(.secondary)
                HStack(spacing: AppSpacing.micro) {
                    Image(systemName: "calendar").font(.caption2)
                    Text("Target: \(goal.targetDate.formatted(date: .abbreviated, time: .omitted))").font(.caption2)
                }
                .foregroundColor(Color.tertiaryLabel)
            }
            Spacer()
            let percentage = goal.targetAmount > 0 ? Int((currentAmount / goal.targetAmount) * 100) : (currentAmount > 0 ? 100 : 0)
            Text("\(percentage)%").font(.system(.headline, design: .rounded)).foregroundColor(.primary)
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: AppRadius.medium))
    }
}
