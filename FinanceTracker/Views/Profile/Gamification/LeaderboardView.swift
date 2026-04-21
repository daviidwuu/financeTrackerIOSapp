import SwiftUI

// LeaderboardView struct removed - logic moved to SocialDashboardView.swift
// Keeping subviews for reuse

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
    @EnvironmentObject var appState: AppState
    
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
                    color: appState.userResolver.resolveAvatarColor(for: entry.id).map { Color(hex: $0) } ?? Color.random(seed: entry.name),
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
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(rank == 1 ? .headline : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if entry.isPremium {
                        PremiumBadge(size: .small, overrideBadgeType: entry.badgeType)
                    }
                }

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
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: AppSpacing.element) {
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
                color: appState.userResolver.resolveAvatarColor(for: entry.id).map { Color(hex: $0) } ?? Color.random(seed: entry.name),
                size: AppSize.avatarSmall
            )

            // Name
            HStack(spacing: 8) {
                Text(entry.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                if entry.isPremium {
                    PremiumBadge(size: .small, overrideBadgeType: entry.badgeType)
                }
            }

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
        .appCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(isCurrentUser ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}
