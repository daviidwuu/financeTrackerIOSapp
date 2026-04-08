// MARK: - FC_Cards.swift
// Frontend layer — Card component catalog for Figma.
// Sources:
//   Views/Components/SpendingCard.swift
//   DesignSystem.swift (.appCardStyle view modifier)

import SwiftUI

// MARK: - Preview Catalog

#Preview("SpendingCard — All Variants") {
    // Small stat card: icon circle + label + amount
    // Used in: WalletDetailsView (net worth breakdown), HomeView spending stats
    ScrollView {
        VStack(spacing: AppSpacing.section) {
            Text("SpendingCard").font(AppTypography.sectionHeader)

            // Two-column grid (standard usage in WalletDetails)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: AppSpacing.element) {
                SpendingCard(title: "Total Spent",   amount: 355.13,   icon: "arrow.down.circle.fill",   color: .red)
                SpendingCard(title: "Total Income",  amount: 4200.00,  icon: "arrow.up.circle.fill",     color: .green)
                SpendingCard(title: "Savings Rate",  amount: 920.87,   icon: "chart.line.uptrend.xyaxis", color: .blue)
                SpendingCard(title: "Net Worth",     amount: 14820.50, icon: "banknote.fill",             color: Color(hex: "#F5A623"))
            }
            .padding(.horizontal, AppSpacing.margin)

            Text("Single Card").font(AppTypography.headline)
            SpendingCard(title: "Budget Used", amount: 355.13, icon: "gauge.medium", color: .orange)
                .padding(.horizontal, AppSpacing.margin)
        }
        .padding(.vertical, AppSpacing.section)
    }
    .background(Color.backgroundPrimary.ignoresSafeArea())
}

#Preview("AppCardStyle — Container Modifier") {
    // .appCardStyle() wraps any view in padding + cardBackground + corner radius
    VStack(spacing: AppSpacing.element) {
        Text(".appCardStyle() — default (radius: medium = 16)")
            .font(AppTypography.caption)
            .foregroundColor(.secondary)

        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text("Balance")
                .font(AppTypography.subheadline)
                .foregroundColor(.secondary)
            Text("$14,820.50")
                .font(AppTypography.prominentBalance)
        }
        .appCardStyle()

        Text(".appCardStyle(radius: .card = 20)")
            .font(AppTypography.caption)
            .foregroundColor(.secondary)

        Text("A card with larger radius")
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle(radius: AppRadius.card)

        Text(".appCardStyle(radius: .large = 28)")
            .font(AppTypography.caption)
            .foregroundColor(.secondary)

        Text("Onboarding-style card")
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle(radius: AppRadius.large)
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
}

#Preview("Social Stat Cards (SocialOverviewCards)") {
    // FC/Component/SocialStatCard — balance chip used in GroupDetailView / FriendDetailView
    // Exact visual: colored pill with "You owe" / "You are owed" label + amount
    VStack(spacing: AppSpacing.element) {
        Text("Social Balance Cards").font(AppTypography.sectionHeader)
            .padding(.horizontal, AppSpacing.margin)

        HStack(spacing: AppSpacing.element) {
            // You owe state
            VStack(alignment: .leading, spacing: 4) {
                Text("YOU OWE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text("$45.00")
                    .font(AppTypography.headline)
                    .foregroundColor(Color.functionalError)
            }
            .padding(AppSpacing.element)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)

            // You are owed state
            VStack(alignment: .leading, spacing: 4) {
                Text("YOU'RE OWED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text("$120.00")
                    .font(AppTypography.headline)
                    .foregroundColor(Color.functionalSuccess)
            }
            .padding(AppSpacing.element)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
        }
        .padding(.horizontal, AppSpacing.margin)

        // Settled state
        VStack(alignment: .leading, spacing: 4) {
            Text("ALL SETTLED UP")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text("$0.00")
                .font(AppTypography.headline)
                .foregroundColor(.secondary)
        }
        .padding(AppSpacing.element)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
        .padding(.horizontal, AppSpacing.margin)
    }
    .padding(.vertical, AppSpacing.section)
    .background(Color.backgroundPrimary.ignoresSafeArea())
}

#Preview("Home Balance Card") {
    // The main balance card as it appears on HomeView
    // Contains: "Balance" label, large amount, spent/left toggle, progress bar
    VStack(spacing: AppSpacing.element) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Balance")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$\(String(format: "%.2f", FC_MockData.totalSpent))")
                    .font(AppTypography.prominentBalance)
                    .foregroundColor(.primary)

                Text("spent")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Capsule progress bar (budget utilization)
            let progress = FC_MockData.totalSpent / FC_MockData.totalBudget
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondaryCardBackground)
                        .frame(height: 8)

                    Capsule()
                        .fill(progress > 0.9 ? Color.functionalError : Color.themeAccent)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 8)

            HStack {
                Text("of $\(String(format: "%.2f", FC_MockData.totalBudget)) budget")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progress * 100))% used")
                    .font(.caption)
                    .foregroundColor(progress > 0.9 ? Color.functionalError : .secondary)
            }
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
        .padding(.horizontal, AppSpacing.margin)
    }
    .padding(.vertical, AppSpacing.section)
    .background(Color.backgroundPrimary.ignoresSafeArea())
}
