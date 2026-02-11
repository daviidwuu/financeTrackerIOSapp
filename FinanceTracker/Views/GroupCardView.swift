import SwiftUI

struct GroupCardView: View {
    let group: FirestoreModels.Group
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    var gradient: LinearGradient {
        Color.GradientTheme.gradient(for: group.color)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Gradient Icon
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 48, height: 48)
                    .shadow(color: Color(hex: group.color).opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: group.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(group.members.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .contentShape(Rectangle()) // Ensures tap area is good
    }
}

// Preview Helper
struct GroupCardView_Previews: PreviewProvider {
    static var previews: some View {
        GroupCardView(group: FirestoreModels.Group(
            name: "Travel Crew",
            normalizedName: "travel crew",
            members: ["1", "2", "3"],
            createdBy: "user1",
            icon: "airplane",
            color: "#FF5733",
            createdAt: Date(),
            updatedAt: Date()
        ))
        .padding()
        .background(Color.systemBackground)
        .previewLayout(.sizeThatFits)
    }
}
