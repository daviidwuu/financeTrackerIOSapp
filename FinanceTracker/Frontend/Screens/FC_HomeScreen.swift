// MARK: - FC_HomeScreen.swift
// Frontend layer — Home tab screen preview for Figma.
// Source: Views/Home/HomeView.swift
//
// Static replica showing the exact layout of the Home screen.
// No Firebase, no @EnvironmentObject. All data from FC_MockData.

import SwiftUI

// MARK: - Screen Preview

#Preview("Home Screen — Default State") {
    FC_HomeScreenView()
        .previewDisplayName("Home — Default")
}

#Preview("Home Screen — Dark Mode") {
    FC_HomeScreenView()
        .preferredColorScheme(.dark)
        .previewDisplayName("Home — Dark")
}

// MARK: - Static View Implementation

private struct FC_HomeScreenView: View {
    @State private var showRemainingBudget = false

    private let transactions = Array(FC_MockData.transactions.prefix(6))
    private let totalSpent  = FC_MockData.totalSpent
    private let totalBudget = FC_MockData.totalBudget
    private let user        = FC_MockData.userProfile
    private let streak      = FC_MockData.userProfile.streakCount

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.backgroundPrimary.ignoresSafeArea()

                List {
                    // Scroll tracker
                    ScrollOffsetTracker()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

                    // Top spacer to clear the overlay header
                    Color.clear.frame(height: 44)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    // MARK: Balance Card
                    Section {
                        balanceCard
                            .appListRow()
                    }

                    // MARK: Recent Transactions header
                    Section {
                        HStack {
                            Text("Recent Transactions")
                                .font(AppTypography.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("See all")
                                .font(AppTypography.caption)
                                .foregroundColor(Color.themeAccent)
                        }
                        .appListRow()
                        .padding(.top, AppSpacing.compact)
                    }

                    // MARK: Transaction Rows
                    Section {
                        ForEach(transactions) { tx in
                            let cat = FC_MockData.category(id: tx.categoryId)
                            FC_TransactionRowView(
                                categoryIcon:   cat.icon,
                                categoryColor:  cat.color,
                                categoryName:   cat.name,
                                note:           tx.note,
                                date:           tx.date,
                                amount:         tx.amount,
                                hasSplit:       tx.hasSplit,
                                originalAmount: nil,
                                currencyCode:   nil
                            )
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)
                            .appListRow()
                        }
                    }

                    Color.clear.frame(height: 80)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                // MARK: Overlay Header
                overlayHeader
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Balance Card

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.element) {
            // Amount toggle row
            VStack(alignment: .leading, spacing: 8) {
                Text("Balance")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$\(String(format: "%.2f", showRemainingBudget ? (totalBudget - totalSpent) : totalSpent))")
                        .font(AppTypography.prominentBalance)
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())

                    Text(showRemainingBudget ? "left" : "spent")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showRemainingBudget.toggle()
                    }
                }

                // Budget progress bar
                let progress = totalSpent / totalBudget
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondaryCardBackground).frame(height: 8)
                        Capsule()
                            .fill(progress > 0.9 ? Color.functionalError : Color.themeAccent)
                            .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("of $\(String(format: "%.2f", totalBudget)) budget")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(totalSpent / totalBudget * 100))% used")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - Overlay Header

    private var overlayHeader: some View {
        HStack {
            // Left: greeting + streak
            VStack(alignment: .leading, spacing: 2) {
                Text("Home")
                    .font(AppTypography.titleDisplay)
                    .foregroundColor(.primary)
            }

            Spacer()

            // Right: streak + missions + bell + avatar
            HStack(spacing: AppSpacing.compact) {
                // Streak pill
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                    Text("\(streak)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.cardBackground)
                .clipShape(Capsule())

                // Trophy / missions
                ZStack {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    CircularProgressView(progress: 0.6, lineWidth: 3, color: Color(hex: "#F5A623"))
                        .frame(width: 36, height: 36)
                }
                .frame(width: AppSize.iconButton, height: AppSize.iconButton)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())

                // Bell
                Image(systemName: "bell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: AppSize.iconButton, height: AppSize.iconButton)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())

                // Profile avatar
                ProfileAvatar(text: user.initial, color: user.color, size: 36)
            }
        }
        .padding(.horizontal, AppSpacing.margin)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.backgroundPrimary)
    }
}
