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
    
    // Search State
    @State private var usernameQuery = ""
    @State private var isSearching = false
    @State private var searchResults: [FriendRepository.UserSearchResult] = []
    @State private var searchMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Segmented Control
                Picker("View", selection: $selectedTab) {
                    Text("Friends").tag(0)
                    Text("Groups").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                if selectedTab == 0 {
                    // MARK: - Friends Tab
                    
                    // Search Section
                    MenuSection("Add Friend") {
                         VStack(alignment: .leading, spacing: 12) {
                             // Search Bar
                             HStack {
                                 Image(systemName: "magnifyingglass")
                                     .foregroundColor(.secondary)
                                 TextField("Search by username", text: $usernameQuery)
                                     .autocapitalization(.none)
                                     .disableAutocorrection(true)
                                     .submitLabel(.search)
                                     .onSubmit {
                                         performSearch()
                                     }
                                 
                                 if !usernameQuery.isEmpty {
                                     Button(action: {
                                         usernameQuery = ""
                                         isSearching = false
                                         searchResults = []
                                         searchMessage = nil
                                     }) {
                                         Image(systemName: "xmark.circle.fill")
                                             .foregroundColor(.secondary)
                                     }
                                 }
                             }
                             
                             if isSearching {
                                 ProgressView().padding(.vertical, 8)
                             } else if let msg = searchMessage {
                                 Text(msg)
                                     .font(.caption)
                                     .foregroundColor(msg.contains("Added") ? .green : .secondary)
                                     .padding(.vertical, 4)
                             }
                             
                             // Search Results List
                             if !searchResults.isEmpty {
                                 ForEach(searchResults) { user in
                                     HStack {
                                         VStack(alignment: .leading) {
                                             Text(user.name).font(.subheadline)
                                             Text("@\(user.username)").font(.caption).foregroundColor(.secondary)
                                         }
                                         Spacer()
                                         Button("Add") {
                                             addFriend(user: user)
                                         }
                                         .font(.caption)
                                         .padding(.horizontal, 12)
                                         .padding(.vertical, 6)
                                         .background(Color.blue)
                                         .foregroundColor(.white)
                                         .cornerRadius(12)
                                     }
                                     .padding(.vertical, 4)
                                     Divider()
                                 }
                             }
                         }
                         .padding(16)
                    }
                    
                    // Invite Section
                    MenuSection {
                        ShareLink(item: URL(string: "https://testflight.apple.com/join/NgxWK8PZ")!) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                                Text("Invite Friends to App")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                        }
                    }
                    
                    MenuSection("My Friends") {
                        if friendRepo.friends.isEmpty {
                            Text("No friends yet. Add them when splitting a bill!")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(friendRepo.friends) { friend in
                                HStack(spacing: 16) {
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
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text("@\(friend.username)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Remove Action
                                    Button(action: {
                                        friendToDelete = friend
                                        showDeleteConfirmation = true
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundColor(.red.opacity(0.8))
                                            .padding(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color(UIColor.secondarySystemBackground))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        friendToDelete = friend
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                                
                                if friend.id != friendRepo.friends.last?.id {
                                    MenuDivider()
                                }
                            }
                        }
                    }
                    
                    Text("Long press or tap trash icon to remove.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                } else {
                    // MARK: - Groups Tab
                    if appState.groupRepo.groups.isEmpty {
                         VStack(spacing: 12) {
                             Image(systemName: "person.3.fill")
                                 .font(.system(size: 40))
                                 .foregroundColor(.gray.opacity(0.5))
                             Text("No groups created yet")
                                 .font(.body)
                                 .foregroundColor(.secondary)
                         }
                         .frame(maxWidth: .infinity)
                         .padding(.top, 40)
                    } else {
                        MenuSection("My Groups") {
                            ForEach(appState.groupRepo.groups) { group in
                                Button(action: {
                                    groupToEdit = group
                                }) {
                                    // Assuming GroupCardView fits well here, or we wrap it
                                    // If GroupCardView has its own padding/background, we might need to adjust.
                                    // For now, let's treat it as a row content.
                                    GroupCardView(group: group)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        groupToEdit = group
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        groupToDelete = group
                                        showGroupDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                
                                if group.id != appState.groupRepo.groups.last?.id {
                                    MenuDivider()
                                }
                            }
                        }
                        
                         Text("Tap to edit, long press to delete.")
                             .font(.caption)
                             .foregroundColor(.secondary)
                             .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .padding(.bottom, 20)
        }
        .background(Color(UIColor.systemBackground))
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
        .alert(
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
        .alert(
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
    
    private func performSearch() {
         guard !usernameQuery.isEmpty else { return }
         isSearching = true
         searchMessage = nil
         Task {
             do {
                 let results = try await friendRepo.searchUsers(username: usernameQuery)
                 
                 await MainActor.run {
                     self.isSearching = false
                     self.searchResults = results
                     if results.first != nil && results.count == 1 {
                          // HapticManager.shared.success() // Optional: Auto-add if desired, but user asked for "Add" button flow implicitly by asking for search bar to add
                     } else if results.isEmpty {
                         self.searchMessage = "No user found with that username."
                     }
                 }
             } catch {
                 await MainActor.run {
                     self.isSearching = false
                     self.searchMessage = "Error searching: \(error.localizedDescription)"
                 }
             }
         }
     }
     
     private func addFriend(user: FriendRepository.UserSearchResult) {
         guard !appState.currentUserId.isEmpty else { return }
         
         Task {
             do {
                 try await friendRepo.addFriend(
                     currentUserId: appState.currentUserId,
                     currentUserInfo: (username: appState.currentUserUsername, name: appState.userName, email: appState.userEmail),
                     targetUser: user
                 )
                 await MainActor.run {
                     HapticManager.shared.success()
                     self.searchMessage = "Added \(user.name)!"
                     self.searchResults = []
                     self.usernameQuery = ""
                 }
             } catch {
                 await MainActor.run {
                     self.searchMessage = "Failed to add: \(error.localizedDescription)"
                 }
             }
         }
     }
}

#Preview {
    NavigationView {
        FriendsListView()
            .environmentObject(AppState.shared)
    }
}
