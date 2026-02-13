import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var repo: SocialRepository
    @EnvironmentObject var appState: AppState
    var filter: String = ""
    
    var filteredData: [SocialRepository.LeaderboardEntry] {
        if filter.isEmpty {
            return repo.leaderboardData
        } else {
            return repo.leaderboardData.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.section) {
                if repo.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if filteredData.isEmpty {
                    EmptyStateView(
                        icon: "trophy",
                        title: "Leaderboard",
                        message: filter.isEmpty ? "Compare your gamification points with friends!" : "No results found."
                    )
                    .padding(.top, 40)
                } else {
                    // 1. Podium for Top 3 (Only if filter is empty to show true leaders)
                    if filter.isEmpty && !filteredData.isEmpty {
                        PodiumView(topUsers: Array(filteredData.prefix(3)))
                            .padding(.top, 20)
                    }
                    
                    // 2. List for the rest (or all if filtered)
                    LazyVStack(spacing: AppSpacing.element) {
                        let startIndex = (filter.isEmpty && filteredData.count > 3) ? 3 : 0
                        let dataToShow = (filter.isEmpty && filteredData.count > 3) ? Array(filteredData.dropFirst(3)) : filteredData
                        
                        ForEach(Array(dataToShow.enumerated()), id: \.element.id) { index, entry in
                            LeaderboardRow(
                                entry: entry,
                                rank: startIndex + index + 1,
                                isCurrentUser: entry.id == appState.currentUserId
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.bottom, 100) // Spacing for scrolling
                }
            }
        }
        .background(Color.backgroundPrimary) // Ensure consistent specific background
        .onAppear {
            if repo.leaderboardData.isEmpty {
                repo.fetchLeaderboard(
                    friends: appState.friendRepo.friends,
                    currentUser: (id: appState.currentUserId, name: appState.userName)
                )
            }
        }
    }
}

struct PodiumView: View {
    let topUsers: [SocialRepository.LeaderboardEntry]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Rank 2 (Left)
            if topUsers.count >= 2 {
                PodiumUser(entry: topUsers[1], rank: 2)
            }
            
            // Rank 1 (Center, Big)
            if topUsers.count >= 1 {
                PodiumUser(entry: topUsers[0], rank: 1)
                    .zIndex(1) // Determine z-index ensuring center is on top visually if overlap
            }
            
            // Rank 3 (Right)
            if topUsers.count >= 3 {
                PodiumUser(entry: topUsers[2], rank: 3)
            }
        }
        .padding(.horizontal)
    }
}

struct PodiumUser: View {
    let entry: SocialRepository.LeaderboardEntry
    let rank: Int
    
    var scale: CGFloat {
        rank == 1 ? 1.2 : 0.9
    }
    
    var ringColor: Color {
        switch rank {
        case 1: return Color(hex: "#FFD700") // Gold
        case 2: return Color(hex: "#C0C0C0") // Silver
        case 3: return Color(hex: "#CD7F32") // Bronze
        default: return .clear
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Crown for #1
            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(ringColor)
                    .padding(.bottom, -4)
            }
            
            // Avatar
            ZStack {
                Circle()
                    .stroke(ringColor, lineWidth: 3)
                    .frame(width: 72 * scale, height: 72 * scale)
                
                ProfileAvatar(
                    text: String(entry.name.prefix(1)),
                    color: Color.random(seed: entry.name),
                    size: 64 * scale
                )
                
                // Rank Badge
                VStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(ringColor)
                            .frame(width: 24, height: 24)
                        Text("\(rank)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .offset(y: 12)
                }
            }
            .frame(width: 72 * scale, height: 72 * scale + 12) // Adjust for badge offset
            
            VStack(spacing: 2) {
                Text(entry.name)
                    .font(rank == 1 ? .headline : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(entry.points)")
                    .font(.system(size: rank == 1 ? 18 : 14, weight: .bold, design: .rounded))
                    .foregroundColor(ringColor)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct LeaderboardRow: View {
    let entry: SocialRepository.LeaderboardEntry
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(rank)")
                .font(.subheadline)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            // Avatar
            ProfileAvatar(
                text: String(entry.name.prefix(1)),
                color: Color.random(seed: entry.name),
                size: 40
            )
            
            // Name
            Text(entry.name)
                .font(.body)
                .fontWeight(isCurrentUser ? .semibold : .medium)
                .foregroundColor(.primary)
            
            if isCurrentUser {
                Text("(You)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Points (Pill)
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text("\(entry.points)")
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(UIColor.tertiarySystemFill))
            .clipShape(Capsule())
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(isCurrentUser ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}
