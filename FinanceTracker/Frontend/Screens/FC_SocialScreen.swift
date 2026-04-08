// MARK: - FC_SocialScreen.swift
// Frontend layer — Social tab screen preview for Figma.
// Source: Views/Social/SocialDashboardView.swift
//
// Shows all 3 segments: Groups / Friends / Leaderboard

import SwiftUI

#Preview("Social — Groups Segment") {
    FC_SocialScreenView(segment: 0)
        .previewDisplayName("Social — Groups")
}

#Preview("Social — Friends Segment") {
    FC_SocialScreenView(segment: 1)
        .previewDisplayName("Social — Friends")
}

#Preview("Social — Leaderboard Segment") {
    FC_SocialScreenView(segment: 2)
        .previewDisplayName("Social — Leaderboard")
}

#Preview("Social — Dark Mode") {
    FC_SocialScreenView(segment: 0)
        .preferredColorScheme(.dark)
        .previewDisplayName("Social — Dark")
}

// MARK: - Static View Implementation

private struct FC_SocialScreenView: View {
    @State private var selectedSegment: Int
    @State private var searchText = ""

    private let groups  = FC_MockData.groups
    private let friends = FC_MockData.friends

    init(segment: Int = 0) {
        _selectedSegment = State(initialValue: segment)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    // Search + Segment
                    VStack(spacing: AppSpacing.element) {
                        SearchBar(text: $searchText,
                                  placeholder: selectedSegment == 0 ? "Search groups..." : "Search friends...")
                            .padding(.horizontal, AppSpacing.margin)

                        // Custom segmented control
                        HStack(spacing: 0) {
                            ForEach(["Groups", "Friends", "Leaderboard"].indices, id: \.self) { i in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedSegment = i
                                    }
                                } label: {
                                    Text(["Groups", "Friends", "Leaderboard"][i])
                                        .font(AppTypography.subheadline)
                                        .fontWeight(selectedSegment == i ? .semibold : .regular)
                                        .foregroundColor(selectedSegment == i ? .primary : .secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedSegment == i
                                                ? Color.cardBackground
                                                : Color.clear
                                        )
                                        .cornerRadius(AppRadius.small)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(Color.secondaryCardBackground)
                        .cornerRadius(AppRadius.medium)
                        .padding(.horizontal, AppSpacing.margin)
                    }

                    // Content
                    List {
                        Color.clear.frame(height: AppSpacing.compact)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        switch selectedSegment {
                        case 0: groupRows
                        case 1: friendRows
                        case 2: leaderboardRows
                        default: EmptyView()
                        }

                        Color.clear.frame(height: 80)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                // Overlay header
                OverlayHeaderView(
                    mode: .root(
                        title: "Social",
                        subtitle: nil,
                        trailing: AnyView(
                            Button {} label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: AppSize.iconButton, height: AppSize.iconButton)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        )
                    ),
                    scrollOffset: 0
                )
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Groups

    @ViewBuilder
    private var groupRows: some View {
        ForEach(groups) { group in
            groupCard(group)
                .appListRow()
        }
    }

    private func groupCard(_ group: MockGroup) -> some View {
        HStack(spacing: AppSpacing.element) {
            GroupAvatar(icon: group.icon, color: group.colorHex, size: AppSize.avatarList)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(AppTypography.headline)
                    .foregroundColor(.primary)
                Text("\(group.memberCount) members")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(group.totalBalance >= 0 ? "+" : "")$\(String(format: "%.2f", abs(group.totalBalance)))")
                    .font(AppTypography.headline)
                    .foregroundColor(group.totalBalance >= 0 ? Color.functionalSuccess : Color.functionalError)
                Text(group.totalBalance >= 0 ? "you're owed" : "you owe")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            CardChevron()
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - Friends

    @ViewBuilder
    private var friendRows: some View {
        ForEach(friends) { friend in
            friendCard(friend)
                .appListRow()
        }
    }

    private func friendCard(_ friend: MockFriend) -> some View {
        HStack(spacing: AppSpacing.element) {
            ProfileAvatar(text: friend.initial, color: friend.color, size: AppSize.avatarList)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(AppTypography.headline)
                    .foregroundColor(.primary)
                Text("@\(friend.username)")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if friend.owedAmount != 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(friend.owedAmount > 0 ? "+" : "")$\(String(format: "%.2f", abs(friend.owedAmount)))")
                        .font(AppTypography.headline)
                        .foregroundColor(friend.owedAmount > 0 ? Color.functionalSuccess : Color.functionalError)
                    Text(friend.owedAmount > 0 ? "owes you" : "you owe")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Settled")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }

            CardChevron()
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - Leaderboard

    @ViewBuilder
    private var leaderboardRows: some View {
        // Podium (top 3)
        Section {
            podiumView
                .appListRow()
                .padding(.bottom, AppSpacing.element)
        }

        // Ranked list (4+)
        ForEach(Array(leaderboardEntries.dropFirst(3).enumerated()), id: \.offset) { i, entry in
            HStack(spacing: AppSpacing.element) {
                Text("#\(i + 4)")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 28)

                ProfileAvatar(text: String(entry.name.prefix(1)), color: entry.color, size: AppSize.avatarMedium)

                Text(entry.name)
                    .font(AppTypography.headline)

                Spacer()

                Text("\(entry.points) pts")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
            .appListRow()
        }
    }

    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.element) {
            // #2
            podiumSlot(entry: leaderboardEntries[1], rank: 2, height: 80)
            // #1
            podiumSlot(entry: leaderboardEntries[0], rank: 1, height: 110)
            // #3
            podiumSlot(entry: leaderboardEntries[2], rank: 3, height: 60)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.element)
    }

    private func podiumSlot(entry: (name: String, points: Int, color: Color), rank: Int, height: CGFloat) -> some View {
        VStack(spacing: AppSpacing.compact) {
            if rank == 1 {
                Image(systemName: "crown.fill")
                    .foregroundColor(Color(hex: "#F5A623"))
                    .font(.title2)
            }
            ProfileAvatar(text: String(entry.name.prefix(1)), color: entry.color, size: AppSize.avatarMedium)
            Text(entry.name.components(separatedBy: " ").first ?? entry.name)
                .font(AppTypography.caption)
                .fontWeight(.semibold)
            Text("\(entry.points)")
                .font(.caption2)
                .foregroundColor(.secondary)

            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(Color.secondaryCardBackground)
                .frame(height: height)
                .overlay(
                    Text("#\(rank)")
                        .font(AppTypography.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.top, AppSpacing.compact),
                    alignment: .top
                )
        }
        .frame(maxWidth: .infinity)
    }

    private let leaderboardEntries: [(name: String, points: Int, color: Color)] = [
        ("David W.", 2450, Color(hex: "#FF9500")),
        ("Alex R.",  1820, Color(hex: "#007AFF")),
        ("Sam T.",   1560, Color(hex: "#AF52DE")),
        ("Jordan K.",1200, Color(hex: "#34C759")),
        ("Morgan L.", 980, Color(hex: "#FF2D55")),
    ]
}
