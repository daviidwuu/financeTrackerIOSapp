// MARK: - FC_WalletScreen.swift
// Frontend layer — Wallet tab screen preview for Figma.
// Source: Views/Wallet/WalletView.swift
//
// Shows: Net Worth card, Saving Goals, Budgets, Recurring Transactions.

import SwiftUI

#Preview("Wallet Screen — Default") {
    FC_WalletScreenView()
        .previewDisplayName("Wallet — Default")
}

#Preview("Wallet Screen — Dark Mode") {
    FC_WalletScreenView()
        .preferredColorScheme(.dark)
        .previewDisplayName("Wallet — Dark")
}

// MARK: - Static View Implementation

private struct FC_WalletScreenView: View {
    private let goals       = FC_MockData.savingGoals
    private let budgets     = FC_MockData.budgets
    private let recurring   = FC_MockData.recurringTransactions
    private let netWorth    = FC_MockData.netWorth

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.element) {
                        ScrollOffsetTracker()
                        Spacer().frame(height: 56)

                        // MARK: Net Worth Card
                        netWorthCard
                            .padding(.horizontal, AppSpacing.margin)

                        // MARK: Saving Goals
                        sectionHeader("Saving Goals", trailing: "Add Goal")
                        ForEach(goals) { goal in
                            savingGoalRow(goal)
                                .padding(.horizontal, AppSpacing.margin)
                        }

                        // MARK: Budgets
                        sectionHeader("Budgets", trailing: "Add Budget")
                        ForEach(budgets) { budget in
                            let cat = FC_MockData.category(id: budget.categoryId)
                            budgetRow(budget, category: cat)
                                .padding(.horizontal, AppSpacing.margin)
                        }

                        // MARK: Recurring Transactions
                        sectionHeader("Recurring", trailing: "Add")
                        ForEach(recurring) { item in
                            recurringRow(item)
                                .padding(.horizontal, AppSpacing.margin)
                        }

                        Spacer().frame(height: AppSpacing.section)
                    }
                }

                // Overlay header
                OverlayHeaderView(
                    mode: .root(title: "Wallet"),
                    scrollOffset: 0
                )
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Net Worth Card

    private var netWorthCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.element) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Worth")
                        .font(AppTypography.subheadline)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", netWorth))")
                        .font(AppTypography.prominentBalance)
                        .foregroundColor(.primary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }

            // Spending stats (2-column)
            HStack(spacing: AppSpacing.element) {
                SpendingCard(title: "Spent",  amount: FC_MockData.totalSpent,  icon: "arrow.down.circle.fill", color: .red)
                SpendingCard(title: "Income", amount: FC_MockData.userProfile.monthlyIncome, icon: "arrow.up.circle.fill", color: .green)
            }
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.headline)
                .foregroundColor(.primary)
            Spacer()
            Text(trailing)
                .font(AppTypography.caption)
                .foregroundColor(Color.themeAccent)
        }
        .padding(.horizontal, AppSpacing.margin)
        .padding(.top, AppSpacing.compact)
    }

    // MARK: - Saving Goal Row

    private func savingGoalRow(_ goal: MockSavingGoal) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            HStack {
                IconAvatar(systemName: goal.icon, color: goal.color, size: AppSize.avatarList)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(AppTypography.headline)
                    Text("$\(String(format: "%.0f", goal.currentAmount)) of $\(String(format: "%.0f", goal.targetAmount))")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(goal.progress * 100))%")
                        .font(AppTypography.headline)
                    Text("$\(String(format: "%.0f", goal.targetAmount - goal.currentAmount)) left")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondaryCardBackground).frame(height: 6)
                    Capsule()
                        .fill(goal.color)
                        .frame(width: geo.size.width * goal.progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - Budget Row

    private func budgetRow(_ budget: MockBudget, category: MockCategory) -> some View {
        HStack {
            IconAvatar(systemName: category.icon, color: category.color, size: AppSize.avatarList)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(AppTypography.headline)

                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondaryCardBackground).frame(height: 4)
                        Capsule()
                            .fill(budget.progress > 0.9 ? Color.functionalError : category.color)
                            .frame(width: geo.size.width * budget.progress, height: 4)
                    }
                }
                .frame(height: 4)

                Text("$\(String(format: "%.0f", budget.spent)) of $\(String(format: "%.0f", budget.limit))")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("$\(String(format: "%.0f", budget.remaining)) left")
                .font(AppTypography.caption)
                .foregroundColor(budget.progress > 0.9 ? Color.functionalError : .secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - Recurring Row

    private func recurringRow(_ item: MockRecurring) -> some View {
        HStack {
            IconAvatar(systemName: item.icon, color: item.color, size: AppSize.avatarList)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(AppTypography.headline)
                Text(item.frequency)
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(item.amount >= 0 ? "+" : "")$\(String(format: "%.2f", abs(item.amount)))")
                .font(AppTypography.headline)
                .fontWeight(.bold)
                .foregroundColor(item.amount >= 0 ? Color.functionalSuccess : .primary)
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }
}
