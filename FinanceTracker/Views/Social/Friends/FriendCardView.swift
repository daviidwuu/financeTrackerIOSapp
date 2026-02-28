import SwiftUI

struct FriendCardView: View {
    let friend: FirestoreModels.Friend
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository
    
    var gradient: LinearGradient {
        Color.GradientTheme.gradient(for: friend.avatarColor ?? Color.random(seed: friend.name).toHex() ?? "#007AFF")
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Gradient Icon / Avatar
            ProfileAvatar(
                text: String(friend.name.prefix(1)),
                color: friend.avatarColor.map { Color(hex: $0) } ?? Color.random(seed: friend.name),
                size: AppSize.avatarList
            )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(friend.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let id = friend.id, userPremiumRepo.isPremium(userId: id) == true {
                        PremiumBadge(size: .small)
                    }
                }
                
                Text("@" + (friend.username ?? "user"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
                .accessibilityHidden(true)
        }
        .padding(AppSpacing.element)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
        .onAppear {
            if let id = friend.id {
                userPremiumRepo.prefetch(userIds: [id])
            }
        }
    }
}
