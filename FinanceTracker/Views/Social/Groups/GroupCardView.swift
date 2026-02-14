import SwiftUI

struct GroupCardView: View {
    let group: FirestoreModels.Group
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    var gradient: LinearGradient {
        Color.GradientTheme.gradient(for: group.color)
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Gradient Icon
            GroupAvatar(
                icon: group.icon,
                color: group.color,
                size: AppSize.avatarList
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(group.members.count) members")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
                .accessibilityHidden(true)
        }
        .padding(AppSpacing.element) // Inner padding
        .background(Color(UIColor.secondarySystemBackground)) // Card Background
        .cornerRadius(AppRadius.medium) // Card Radius
        // Shadow is optional per guide ("None by default... ScaleEffect on press")
    }
}
