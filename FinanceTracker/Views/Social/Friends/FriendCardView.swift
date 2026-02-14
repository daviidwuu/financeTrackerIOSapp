import SwiftUI

struct FriendCardView: View {
    let friend: FirestoreModels.Friend
    
    var gradient: LinearGradient {
        Color.GradientTheme.gradient(for: Color.random(seed: friend.name).toHex() ?? "#007AFF")
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Gradient Icon / Avatar
            ProfileAvatar(
                text: String(friend.name.prefix(1)),
                color: Color.random(seed: friend.name),
                size: AppSize.avatarList
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("@" + friend.username)
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
    }
}
