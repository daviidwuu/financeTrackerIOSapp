import SwiftUI

struct FriendCardView: View {
    let friend: FirestoreModels.Friend
    
    var gradient: LinearGradient {
        Color.GradientTheme.gradient(for: Color.random(seed: friend.name).toHex() ?? "#007AFF")
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Gradient Icon / Avatar
            ZStack {
                Circle()
                    .fill(Color.random(seed: friend.name))
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.random(seed: friend.name).opacity(0.3), radius: 4, x: 0, y: 2)
                
                Text(String(friend.name.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("@" + friend.username)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color.tertiaryLabel)
        }
        .padding(.vertical, AppSpacing.compact)
        .contentShape(Rectangle()) // Ensures tap area is good
    }
}
