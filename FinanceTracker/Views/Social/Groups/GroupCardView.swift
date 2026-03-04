import SwiftUI

struct GroupCardView: View {
    let group: FirestoreModels.Group
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.element) {
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

            CardChevron()
        }
        .appCardStyle()
    }
}
