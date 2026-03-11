import SwiftUI

struct FriendCardView: View {
    let friend: FirestoreModels.Friend
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository

    var body: some View {
        HStack(spacing: AppSpacing.element) {
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
                        PremiumBadge(size: .small, overrideBadgeType: userPremiumRepo.badgeType(userId: id))
                    }
                }

                Text("@" + (friend.username ?? "user"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            CardChevron()
        }
        .appCardStyle()
        .onAppear {
            if let id = friend.id {
                userPremiumRepo.prefetch(userIds: [id])
            }
        }
    }
}
