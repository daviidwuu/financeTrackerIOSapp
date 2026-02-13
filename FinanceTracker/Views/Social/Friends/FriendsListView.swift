import SwiftUI
import FirebaseFirestore

struct FriendsListView: View {
    // Repositories
    @StateObject private var friendRepo = FriendRepository()
    @StateObject private var guestRepo = GuestRepository()
    // friendRequestRepo is managed by AppState
    
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteConfirmation = false
    @State private var friendToDelete: FirestoreModels.Friend?
    @State private var errorState = ErrorState()
    
    // Smart Intercept State
    @State private var showSmartInterceptAlert = false
    @State private var interceptedGuest: FirestoreModels.Guest?
    @State private var pendingUserToAdd: FriendRepository.UserSearchResult?
    
    // Group State
    @State var selectedTab = 0 // 0: Friends, 1: Groups
    @State private var showGroupForm = false
    @State private var groupToEdit: FirestoreModels.Group?
    @State private var groupToDelete: FirestoreModels.Group?
    @State private var showGroupDeleteConfirmation = false
    
    // Search State
    @State private var usernameQuery = ""
    @State private var isSearching = false
    @State private var searchResults: [FriendRepository.UserSearchResult] = []
    @State private var searchMessage: String?
    
    
    var friendsTab: some View {
        VStack(spacing: 24) {
            // Search Section
            MenuSection("Add Friend") {
                 VStack(alignment: .leading, spacing: 12) {
                     // Search Bar
                     SearchBar(text: $usernameQuery, placeholder: "Search by username", onSearch: performSearch, isLoading: isSearching)
                     
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
                                 Button("Send Request") { // Changed "Add" to "Send Request"
                                     checkForGuestDuplicates(targetUser: user)
                                 }
                                 .buttonStyle(SmallPrimaryButtonStyle())
                             }
                             .padding(.vertical, 4)
                             Divider()
                         }
                     }
                 }
                 .padding(16)
            }
            
            // Incoming Requests Section
            if !appState.friendRequestRepo.incomingRequests.isEmpty {
                MenuSection("Incoming Requests") {
                    VStack(spacing: 0) {
                        ForEach(appState.friendRequestRepo.incomingRequests) { request in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(request.fromName ?? "Current User")
                                        .font(.headline)
                                    if let username = request.fromUsername {
                                        Text("@\(username)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                HStack(spacing: 12) {
                                    Button {
                                        Task {
                                            do {
                                                try await appState.friendRequestRepo.acceptRequest(request)
                                                await MainActor.run { HapticManager.shared.success() }
                                            } catch {
                                                await MainActor.run {
                                                    errorState.show("Failed to accept request")
                                                    HapticManager.shared.error()
                                                }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.functionalSuccess)
                                            .font(.title2)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        Task {
                                            do {
                                                try await appState.friendRequestRepo.declineRequest(request)
                                                await MainActor.run { HapticManager.shared.error() }
                                            } catch {
                                                await MainActor.run {
                                                    errorState.show("Failed to decline request")
                                                }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.functionalError)
                                            .font(.title2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            
                            if request.id != appState.friendRequestRepo.incomingRequests.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
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
        }
    }
    
    var groupsTab: some View {
        VStack(spacing: 24) {
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
    }
    
    var body: some View {
        mainContent
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
        .errorBanner(errorState)
        .onAppear {
                if !appState.currentUserId.isEmpty {
                    friendRepo.startListening(userId: appState.currentUserId)
                    guestRepo.startListening(userId: appState.currentUserId)
                    // friendRequestRepo and groupRepo are managed by AppState
                }
        }
        .onDisappear {
            friendRepo.stopListening()
            guestRepo.stopListening()
            // friendRequestRepo and groupRepo lifecycle managed by AppState
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
            GroupCreationWizardView()
        }
        .sheet(item: $groupToEdit) { group in
            GroupCreationWizardView(groupToEdit: group)
        }

    
        .alert(
            "Possible Duplicate",
            isPresented: $showSmartInterceptAlert,
            presenting: interceptedGuest
        ) { guest in
            Button("Yes, It's Them (Send Request)", role: .none) {
                // Decision #3: In v2.1, we just proceed. Merging is a future feature.
                if let user = pendingUserToAdd {
                    sendFriendRequest(user: user)
                }
            }
            Button("No, Different Person", role: .cancel) {
                if let user = pendingUserToAdd {
                    sendFriendRequest(user: user)
                }
            }
        } message: { guest in
            Text("You have a guest named '\(guest.name)'. Is this the same person? Sending a request will let them see these transactions.")
        }
    }
    
    private func removeFriend(_ friend: FirestoreModels.Friend) {
        guard let friendId = friend.id else { return }
        
        // Optimistic UI update could be done here if the list was local state, 
        // but since it's repo-driven, we just ensure feedback is fast.
        
        Task {
            do {
                try await friendRepo.deleteFriend(friendId: friendId)
                await MainActor.run {
                    HapticManager.shared.success()
                }
            } catch {
                errorState.show("Failed to remove friend")
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func deleteGroup(_ group: FirestoreModels.Group) {
        guard let groupId = group.id else { return }
        Task {
            do {
                try await appState.groupRepo.deleteGroup(groupId: groupId)
                await MainActor.run {
                    HapticManager.shared.success()
                }
            } catch {
                errorState.show("Failed to delete group")
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
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
                     if results.isEmpty {
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
     
     // MARK: - Smart Intercept Logic
     private func checkForGuestDuplicates(targetUser: FriendRepository.UserSearchResult) {
         let matches = guestRepo.findMatchingGuests(friendName: targetUser.name)
         
         if let firstMatch = matches.first {
             // Found potential duplicate
             interceptedGuest = firstMatch
             pendingUserToAdd = targetUser
             showSmartInterceptAlert = true
         } else {
             // No duplicates, proceed
             sendFriendRequest(user: targetUser)
         }
     }
     
     private func sendFriendRequest(user: FriendRepository.UserSearchResult) {
         guard !appState.currentUserId.isEmpty else { return }
         
         Task {
             do {
                 try await appState.friendRequestRepo.sendFriendRequest(
                    fromUid: appState.currentUserId,
                    fromName: appState.userName, // ✅ Added Name
                    fromUsername: appState.currentUserUsername, // ✅ Added Username
                    toUid: user.id!
                 )
                 await MainActor.run {
                     HapticManager.shared.success()
                     self.searchMessage = "Friend Request Sent to \(user.name)!"
                     self.searchResults = []
                     self.usernameQuery = ""
                 }
             } catch {
                 await MainActor.run {
                     self.searchMessage = "Failed to send request: \(error.localizedDescription)"
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
