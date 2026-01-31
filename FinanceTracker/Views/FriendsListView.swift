import SwiftUI
import FirebaseFirestore

struct FriendsListView: View {
    @StateObject private var friendRepo = FriendRepository()
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteConfirmation = false
    @State private var friendToDelete: FirestoreModels.Friend?
    
    var body: some View {
        List {
            Section {
                if friendRepo.friends.isEmpty {
                    Text("No friends yet. Add them when splitting a bill!")
                        .foregroundColor(.secondary)
                        .padding(.vertical)
                } else {
                    ForEach(friendRepo.friends) { friend in
                        HStack {
                            Circle()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 20))
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.name)
                                    .fontWeight(.medium)
                                Text("@\(friend.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                friendToDelete = friend
                                showDeleteConfirmation = true
                            } label: {
                                Label("Remove", systemImage: "trash.fill")
                            }
                        }
                    }
                }
            } header: {
                Text("My Friends")
            } footer: {
                Text("Swipe left to remove a friend.")
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !appState.currentUserId.isEmpty {
                friendRepo.startListening(userId: appState.currentUserId)
            }
        }
        .onDisappear {
            friendRepo.stopListening()
        }
        .confirmationDialog(
            "Remove Friend?",
            isPresented: $showDeleteConfirmation,
            presenting: friendToDelete
        ) { friend in
            Button("Remove \(friend.name)", role: .destructive) {
                removeFriend(friend)
            }
            Button("Cancel", role: .cancel) {}
        } message: { friend in
            Text("Are you sure you want to remove \(friend.name)? They will also be removed from your lists.")
        }
    }
    
    private func removeFriend(_ friend: FirestoreModels.Friend) {
        guard let friendId = friend.id else { return }
        Task {
            try? await friendRepo.deleteFriend(friendId: friendId)
        }
    }
}

#Preview {
    NavigationView {
        FriendsListView()
            .environmentObject(AppState.shared)
    }
}
