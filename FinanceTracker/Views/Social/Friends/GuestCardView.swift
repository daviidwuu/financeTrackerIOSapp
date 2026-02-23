import SwiftUI

struct GuestCardView: View {
    let guest: FirestoreModels.Guest
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Gradient Icon / Avatar
            ProfileAvatar(
                text: String(guest.name.prefix(1)),
                color: Color(hex: guest.avatarColor ?? "#007AFF") ?? Color.random(seed: guest.name),
                size: AppSize.avatarList
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(guest.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(String(guest.name.split(separator: " ").first ?? "").lowercased() + "_guest")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Guest")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .foregroundColor(.orange)
                .clipShape(Capsule())
            
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
