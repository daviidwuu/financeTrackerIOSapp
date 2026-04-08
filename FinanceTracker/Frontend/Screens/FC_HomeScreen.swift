// MARK: - FC_HomeScreen.swift
// Frontend layer — Home tab screen preview for Figma.
// Source: Views/Home/HomeView.swift — 1:1 verified against source.
//
// Key layout facts confirmed from source:
//   - Header: isWelcomeStyle=true, title="Welcome", subtitle=userName
//   - titleAccessory: orange flame + streak count pill (orange.opacity(0.15) bg)
//   - Trailing: trophy + bell + person.fill icon (all secondary.opacity(0.15) bg circles)
//   - Balance card: AppSpacing.large (24) padding, AppRadius.large (28) radius
//   - Progress bar: 24pt tall Capsule, Color.primary fill (not themeAccent), no color change
//   - Section header: .title2 bold, "View All" with chevron.right in .secondary
//   - NativeAdView appears inline above transaction rows (free users)

import SwiftUI

#Preview("Home Screen — Default") {
    FC_HomeScreenView()
        .previewDisplayName("Home — Default")
}

#Preview("Home Screen — Dark Mode") {
    FC_HomeScreenView()
        .preferredColorScheme(.dark)
        .previewDisplayName("Home — Dark")
}

// MARK: - Static View

private struct FC_HomeScreenView: View {
    @State private var showRemainingBudget = false
    @State private var isAnimating = false

    private let transactions = Array(FC_MockData.transactions.prefix(5))
    private let totalSpent   = FC_MockData.totalSpent
    private let totalBudget  = FC_MockData.totalBudget
    private let user         = FC_MockData.userProfile

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

                    Color.clear.frame(height: 40)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    // MARK: Balance Card
                    Section {
                        balanceCard
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.bottom, AppSpacing.compact)
                    }

                    // MARK: Recent Transactions section header
                    Section(header:
                        HStack {
                            Text("Recent Transactions")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                            HStack(spacing: 4) {
                                Text("View All")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundColor(.secondary)
                        }
                        .textCase(nil)
                    ) {
                        // Native ad placeholder (appears for free users above transactions)
                        MockNativeAdView()
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.bottom, AppSpacing.compact)

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
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.bottom, AppSpacing.compact)
                        }
                    }
                    .listRowBackground(Color.clear)

                    Color.clear.frame(height: 80)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                // MARK: Overlay Header (isWelcomeStyle)
                OverlayHeaderView(
                    mode: .root(
                        title: "Welcome",
                        subtitle: user.name,
                        trailing: AnyView(headerTrailing),
                        titleAccessory: AnyView(streakPill),
                        isWelcomeStyle: true
                    ),
                    scrollOffset: 0
                )
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Balance Card
    // Source: HomeView lines 61–108. Key details:
    //   VStack spacing:20, inner VStack spacing:8
    //   Progress: Capsule height 24, Color.primary fill, shadow(0.05, r:2)
    //   Padding: AppSpacing.large (24), radius: AppRadius.large (28)
    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 20) {
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
            }

            // Pill-shaped 24pt progress bar — Color.primary fill (matches source exactly)
            GeometryReader { geometry in
                Capsule()
                    .fill(Color.secondaryCardBackground)
                    .frame(height: 24)
                    .overlay(
                        Capsule()
                            .fill(Color.primary)
                            .frame(width: min(geometry.size.width * (totalSpent / max(totalBudget, 0.01)), geometry.size.width)),
                        alignment: .leading
                    )
                    .clipShape(Capsule())
            }
            .frame(height: 24)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .padding(AppSpacing.large)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
    }

    // MARK: - Streak Pill (titleAccessory)
    // Source: HomeView lines 310–322
    // Orange flame + count, orange.opacity(0.15) Capsule background
    private var streakPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
            Text("\(user.streakCount)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.orange.opacity(0.15)))
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Header Trailing (trophy + bell + person.fill)
    // Source: HomeView lines 251–307
    // All icons use Color.secondary.opacity(0.15) circle background
    private var headerTrailing: some View {
        HStack(spacing: 8) {
            // Trophy with circular progress ring
            ZStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Circle())

                CircularProgressView(progress: 0.6, color: .primary)
                    .frame(width: 44, height: 44)
            }

            // Bell (with notification badge)
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Circle())

                // Red badge (shown when there are pending requests)
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .offset(x: -2, y: 2)
            }

            // Profile — person.fill icon (not ProfileAvatar)
            Image(systemName: "person.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Circle())
        }
    }
}

// MARK: - Native Ad Placeholder
// Matches the shimmer/card footprint of NativeAdView while Firebase-free.
private struct MockNativeAdView: View {
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(Color.secondaryCardBackground)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondaryCardBackground).frame(width: 120, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondaryCardBackground).frame(width: 80, height: 10)
            }
            Spacer()
            Text("Ad")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.secondary.opacity(0.4)))
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }
}
