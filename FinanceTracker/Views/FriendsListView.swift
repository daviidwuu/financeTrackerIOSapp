import SwiftUI
import FirebaseFirestore

struct FriendsListView: View {
    @StateObject private var friendRepo = FriendRepository()
    
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteConfirmation = false
    @State private var friendToDelete: FirestoreModels.Friend?
    
    // Group State
    @State private var selectedTab = 0 // 0: Friends, 1: Groups
    @State private var showGroupForm = false
    @State private var groupToEdit: FirestoreModels.Group?
    @State private var groupToDelete: FirestoreModels.Group?
    @State private var showGroupDeleteConfirmation = false
    
    var body: some View {
        VStack {
            // Segmented Control
            Picker("View", selection: $selectedTab) {
                Text("Friends").tag(0)
                Text("Groups").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if selectedTab == 0 {
                // MARK: - Friends Tab
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        HapticManager.shared.medium()
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
            } else {
                // MARK: - Groups Tab
                List {
                    Section {
                        if appState.groupRepo.groups.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("No groups created yet")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 32)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(appState.groupRepo.groups) { group in
                                Button(action: {
                                    groupToEdit = group
                                }) {
                                    GroupCardView(group: group)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        HapticManager.shared.medium()
                                        groupToDelete = group
                                        showGroupDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("My Groups")
                    } footer: {
                        Text("Tap to edit, swipe left to delete.")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(selectedTab == 0 ? "Friends" : "Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == 1 {
                    Button(action: {
                        showGroupForm = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            if !appState.currentUserId.isEmpty {
                friendRepo.startListening(userId: appState.currentUserId)
                // groupRepo is now managed by AppState
            }
        }
        .onDisappear {
            friendRepo.stopListening()
            // groupRepo lifecycle managed by AppState
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
        .confirmationDialog(
            "Delete Group?",
            isPresented: $showGroupDeleteConfirmation,
            presenting: groupToDelete
        ) { group in
            Button("Delete \(group.name)", role: .destructive) {
                deleteGroup(group)
            }
            Button("Cancel", role: .cancel) {}
        } message: { group in
            Text("Are you sure you want to delete this group? This action cannot be undone.")
        }
        .sheet(isPresented: $showGroupForm) {
            GroupFormView(groupToEdit: nil)
        }
        .sheet(item: $groupToEdit) { group in
            GroupFormView(groupToEdit: group)
        }
    }
    
    private func removeFriend(_ friend: FirestoreModels.Friend) {
        guard let friendId = friend.id else { return }
        Task {
            try? await friendRepo.deleteFriend(friendId: friendId)
        }
    }
    
    private func deleteGroup(_ group: FirestoreModels.Group) {
        guard let groupId = group.id else { return }
        Task {
            try? await appState.groupRepo.deleteGroup(groupId: groupId)
        }
    }
}

#Preview {
    NavigationView {
        FriendsListView()
            .environmentObject(AppState.shared)
    }
}
