import SwiftUI

struct FriendDetailContainerView: View {
    let friendId: String
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if let friend = appState.friendRepo.friends.first(where: { $0.id == friendId }) {
                FriendDetailView(friend: friend)
            } else {
                VStack {
                    ProgressView()
                    Text("Loading Friend...")
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
