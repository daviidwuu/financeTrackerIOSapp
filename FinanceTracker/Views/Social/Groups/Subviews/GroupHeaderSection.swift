import SwiftUI
import FirebaseFirestore

struct GroupHeaderSection: View {
    let group: FirestoreModels.Group
    let onBack: () -> Void
    let onSettings: () -> Void
    let onMembers: () -> Void
    let onSettle: () -> Void
    let onAddExpense: () -> Void
    let onLeaveGroup: () -> Void
    
    var body: some View {
        SocialDetailHeaderSection(
            title: group.name,
            onBack: onBack,
            onMenu: onSettings,
            avatar: {
                GroupAvatar(
                    icon: group.icon,
                    color: group.color,
                    size: AppSize.avatarHero
                )
            },
            subtitle: {
                SocialHeaderPill(action: onMembers) {
                    Image(systemName: "person.2.fill")
                    Text("\(group.members.count) members")
                }
            },
            onSettle: onSettle,
            onAddExpense: onAddExpense,
            extraActions: {
                Button(action: {
                    HapticManager.shared.medium()
                    onLeaveGroup()
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
            }
        )
    }
}
