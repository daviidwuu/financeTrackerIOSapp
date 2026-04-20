import SwiftUI

struct FriendDetailContainerView: View {
    let friendId: String
    @EnvironmentObject var appState: AppState
    
    private var resolvedFriend: FirestoreModels.Friend? {
        if let friend = appState.friendRepo.friends.first(where: { $0.id == friendId }) {
            return friend
        }
        if let guest = appState.guestRepo.guests.first(where: { $0.id == friendId }) {
            return FirestoreModels.Friend(id: guest.id, name: guest.name, avatarColor: guest.avatarColor)
        }
        return nil
    }

    var body: some View {
        Group {
            if let friend = resolvedFriend {
                FriendDetailView(friend: friend)
            } else {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundPrimary)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
