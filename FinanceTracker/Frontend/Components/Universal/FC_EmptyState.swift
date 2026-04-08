// MARK: - FC_EmptyState.swift
// Frontend layer — EmptyStateView component catalog for Figma.
// Source: Views/Components/EmptyStateView.swift

import SwiftUI

#Preview("EmptyStateView — All Instances") {
    // Centered empty state: large icon + title + message + optional CTA button
    ScrollView {
        VStack(spacing: AppSpacing.section) {
            Text("Empty States").font(AppTypography.sectionHeader)
                .padding(.horizontal, AppSpacing.margin)

            // No transactions (HomeView)
            EmptyStateView(
                icon: "tray.fill",
                title: "No Transactions",
                message: "Your financial journey starts here. Add your first transaction to see it show up!",
                actionTitle: "Add Transaction",
                action: {}
            )
            .appCardStyle()
            .padding(.horizontal, AppSpacing.margin)

            // No friends (SocialDashboard)
            EmptyStateView(
                icon: "person.2.fill",
                title: "No Friends Yet",
                message: "Search by username to add friends and start splitting expenses together.",
                actionTitle: "Find Friends",
                action: {}
            )
            .appCardStyle()
            .padding(.horizontal, AppSpacing.margin)

            // No groups (SocialDashboard)
            EmptyStateView(
                icon: "person.3.fill",
                title: "No Groups",
                message: "Create a group to track shared expenses with multiple people.",
                actionTitle: "Create Group",
                action: {}
            )
            .appCardStyle()
            .padding(.horizontal, AppSpacing.margin)

            // No saving goals (WalletView)
            EmptyStateView(
                icon: "star.fill",
                title: "No Saving Goals",
                message: "Set a savings goal to track your progress toward something special.",
                actionTitle: "Add Goal",
                action: {}
            )
            .appCardStyle()
            .padding(.horizontal, AppSpacing.margin)

            // Without action button
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No Results",
                message: "Try a different search term or adjust your filters."
            )
            .appCardStyle()
            .padding(.horizontal, AppSpacing.margin)
        }
        .padding(.vertical, AppSpacing.section)
    }
    .background(Color.backgroundPrimary.ignoresSafeArea())
}
