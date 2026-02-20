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
        Section {
            DetailHeaderView(
                title: group.name,
                onBack: onBack,
                onMenu: onSettings,
                backgroundColor: Color.backgroundPrimary,
                textColor: .primary,
                avatar: {
                    GroupAvatar(
                        icon: group.icon,
                        color: group.color,
                        size: AppSize.avatarHero
                    )
                },
                subtitle: {
                    Button(action: onMembers) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                            Text("\(group.members.count) members")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.borderless)
                },
                actions: {
                    HStack(spacing: 12) {
            Button(action: {
                HapticManager.shared.light()
                onSettle()
            }) {
                Text("Settle")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color.backgroundPrimary)
                    .padding(.horizontal, AppSpacing.margin)
                    .frame(height: 44)
                    .background(Color.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
                        
                        Button(action: {
                            HapticManager.shared.light()
                            onAddExpense()
                        }) {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundColor(Color.backgroundPrimary)
                                .frame(width: 44, height: 44)
                                .background(Color.primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.borderless)
                        
                        // Leave Group Button
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
                }
            )
        }
    }
}
