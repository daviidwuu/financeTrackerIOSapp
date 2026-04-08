// MARK: - FC_SocialScreen.swift
// Frontend layer — Social tab screen preview for Figma.
// Source: Views/Social/SocialDashboardView.swift — 1:1 verified against source.
//
// Key layout facts confirmed from source:
//   - Header: title="Social", subtitle="Split bills and track shared expenses", NO trailing
//   - CustomSegmentedControl: Color.primary fill Capsule, Color.backgroundPrimary selected text
//     container is secondaryCardBackground clipped to Capsule, padding(5) inset
//   - Segment first, then SearchBar below (in that order in the List)
//   - Groups: DashedAddButton "Create New Group" above group cards
//   - Friends: DashedAddButton "Add Guest" above friend cards
//   - Adaptive banner at bottom (sticky)
//   - Leaderboard: PodiumView for top 3, then ranked rows below

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

// MARK: - Static View

private struct FC_SocialScreenView: View {
    @State private var selectedSegment: Int
    @State private var searchText = ""

    private let groups  = FC_MockData.groups
    private let friends = FC_MockData.friends

    init(segment: Int = 0) {
        _selectedSegment = State(initialValue: segment)
    }

    var searchPlaceholder: String {
        switch selectedSegment {
        case 0: return "Search groups..."
        case 1: return "Search friends..."
        case 2: return "Search leaderboard..."
        default: return "Search..."
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.backgroundPrimary.ignoresSafeArea()

                List {
                    ScrollOffsetTracker()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

                    Color.clear.frame(height: 0)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    // MARK: Segment + Search (segment first, then search)
                    // Source: SocialDashboardView lines 61–72
                    Section {
                        FC_CustomSegmentedControl(
                            selection: $selectedSegment,
                            options: ["Groups", "Friends", "Leaderboard"]
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                        SearchBar(text: $searchText, placeholder: searchPlaceholder)
                            .listRowInsets(EdgeInsets(top: 8, leading: AppSpacing.margin, bottom: 8, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    // MARK: Content
                    switch selectedSegment {
                    case 0: groupRows
                    case 1: friendRows
                    case 2: leaderboardRows
                    default: EmptyView()
                    }

                    // Bottom spacer for ad banner
                    Color.clear.frame(height: 70)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.top, -20)

                // Overlay header — title + subtitle, NO trailing
                OverlayHeaderView(
                    mode: .root(
                        title: "Social",
                        subtitle: "Split bills and track shared expenses"
                    ),
                    scrollOffset: 0
                )

                // Sticky adaptive banner at bottom
                VStack {
                    Spacer()
                    mockBannerAd
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.bottom, AppSpacing.element)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Groups List
    // Source: SocialDashboardView.groupsList
    // Has DashedAddButton "Create New Group" at top, then GroupCardView rows
    @ViewBuilder
    private var groupRows: some View {
        // DashedAddButton first
        DashedAddButton(label: "Create New Group", action: {})
            .appListRow()

        ForEach(groups) { group in
            groupCard(group)
                .appListRow()
        }

        if groups.isEmpty {
            EmptyStateView(
                icon: "person.3.fill",
                title: "No Groups",
                message: "Create a group to start splitting expenses."
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private func groupCard(_ group: MockGroup) -> some View {
        HStack(spacing: AppSpacing.element) {
            GroupAvatar(icon: group.icon, color: group.colorHex, size: AppSize.avatarList)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(group.memberCount) members")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(group.totalBalance >= 0 ? "+" : "")$\(String(format: "%.2f", abs(group.totalBalance)))")
                    .font(.headline)
                    .foregroundColor(group.totalBalance >= 0 ? Color.functionalSuccess : Color.functionalError)
                Text(group.totalBalance >= 0 ? "you're owed" : "you owe")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            CardChevron()
        }
        .appCardStyle()
    }

    // MARK: - Friends List
    // Source: SocialDashboardView.friendsList
    // Has DashedAddButton "Add Guest" at top, then FriendCardView rows
    @ViewBuilder
    private var friendRows: some View {
        // DashedAddButton first
        DashedAddButton(label: "Add Guest", action: {})
            .appListRow()

        ForEach(friends) { friend in
            friendCard(friend)
                .appListRow()
        }

        if friends.isEmpty {
            EmptyStateView(
                icon: "person.2.fill",
                title: "No Friends",
                message: "Add friends to split bills 1-on-1."
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private func friendCard(_ friend: MockFriend) -> some View {
        HStack(spacing: AppSpacing.element) {
            ProfileAvatar(text: friend.initial, color: friend.color, size: AppSize.avatarList)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("@\(friend.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if friend.owedAmount != 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(friend.owedAmount > 0 ? "+" : "")$\(String(format: "%.2f", abs(friend.owedAmount)))")
                        .font(.headline)
                        .foregroundColor(friend.owedAmount > 0 ? Color.functionalSuccess : Color.functionalError)
                    Text(friend.owedAmount > 0 ? "owes you" : "you owe")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Settled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            CardChevron()
        }
        .appCardStyle()
    }

    // MARK: - Leaderboard
    // Source: SocialDashboardView.leaderboardList
    // PodiumView for top 3, then LeaderboardRow for the rest
    @ViewBuilder
    private var leaderboardRows: some View {
        Section {
            podiumView
                .padding(.top, 20)
                .frame(maxWidth: .infinity)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

        ForEach(Array(leaderboardEntries.dropFirst(3).enumerated()), id: \.offset) { i, entry in
            leaderboardRow(entry: entry, rank: i + 4)
                .appListRow()
        }
    }

    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.element) {
            podiumSlot(entry: leaderboardEntries[1], rank: 2, height: 80)
            podiumSlot(entry: leaderboardEntries[0], rank: 1, height: 110)
            podiumSlot(entry: leaderboardEntries[2], rank: 3, height: 60)
        }
        .padding(.horizontal, AppSpacing.margin)
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
                .font(.caption).fontWeight(.semibold)
            Text("\(entry.points) pts")
                .font(.caption2).foregroundColor(.secondary)

            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(Color.secondaryCardBackground)
                .frame(height: height)
                .overlay(
                    Text("#\(rank)")
                        .font(AppTypography.headline).fontWeight(.bold).foregroundColor(.secondary)
                        .padding(.top, AppSpacing.compact),
                    alignment: .top
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func leaderboardRow(entry: (name: String, points: Int, color: Color), rank: Int) -> some View {
        HStack(spacing: AppSpacing.element) {
            Text("#\(rank)")
                .font(.caption).foregroundColor(.secondary).frame(width: 28)
            ProfileAvatar(text: String(entry.name.prefix(1)), color: entry.color, size: AppSize.avatarMedium)
            Text(entry.name).font(.headline)
            Spacer()
            Text("\(entry.points) pts").font(.caption).foregroundColor(.secondary)
        }
        .appCardStyle()
    }

    private let leaderboardEntries: [(name: String, points: Int, color: Color)] = [
        ("David W.", 2450, Color(hex: "#FF9500")),
        ("Alex R.",  1820, Color(hex: "#007AFF")),
        ("Sam T.",   1560, Color(hex: "#AF52DE")),
        ("Jordan K.",1200, Color(hex: "#34C759")),
        ("Morgan L.", 980, Color(hex: "#FF2D55")),
    ]

    // MARK: - Mock Banner Ad
    private var mockBannerAd: some View {
        HStack {
            Text("Advertisement")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text("Ad")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.secondary.opacity(0.4)))
        }
        .padding(AppSpacing.compact)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.small)
        .frame(height: 50)
    }
}

// MARK: - CustomSegmentedControl replica
// Source: SocialDashboardView lines 712–751
// Selected: Color.primary Capsule fill via matchedGeometryEffect, text Color.backgroundPrimary
// Unselected: .secondary text
// Container: secondaryCardBackground, clipShape(Capsule()), padding(5)
private struct FC_CustomSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = index
                    }
                } label: {
                    ZStack {
                        if selection == index {
                            Capsule()
                                .fill(Color.primary)
                                .matchedGeometryEffect(id: "bg", in: ns)
                        }
                        Text(options[index])
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundColor(selection == index ? Color.backgroundPrimary : .secondary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, AppSpacing.compact)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(5)
        .background(Color.secondaryCardBackground)
        .clipShape(Capsule())
    }
}
