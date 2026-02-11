import SwiftUI

struct SocialDashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var repo = SocialRepository() // In a real app, might be shared
    @StateObject private var guestRepo = GuestRepository()
    // Use the existing GroupRepository/FriendRepository from AppState for the lists,
    // but SocialRepository for the advanced feeds/stats.
    
    @State private var searchText = ""
    @State private var selectedSegment = 0 // 0: Groups, 1: Friends
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Social")
                            .font(AppTypography.titleDisplay)
                            .foregroundColor(.primary)
                        Text("Split bills and track shared expenses")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    
                    // Segmented Control
                    Picker("View", selection: $selectedSegment) {
                        Text("Groups").tag(0)
                        Text("Friends").tag(1)
                        Text("Leaderboard").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.margin)
                    
                    // Search Bar
                    // Search Bar
                    SearchBar(text: $searchText, onSearch: performSearch, isLoading: isSearching)
                        .padding(.top, 12)
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.bottom, 16)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if selectedSegment == 0 {
                                groupsList
                            } else if selectedSegment == 1 {
                                friendsList
                            } else {
                                LeaderboardView(repo: repo, filter: searchText) // update LeaderboardView to accept filter
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
                .background(alerts()) // Attach alerts to the main view hierarchy
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddSheet) {
                if selectedSegment == 0 {
                    GroupCreationWizardView()
                } else {
                    GuestInputView { name in
                        createGuest(name: name)
                    }
                    .presentationDetents([.fraction(0.4)])
                }
            }
        }
        .onAppear {
            if !appState.currentUserId.isEmpty {
                 guestRepo.startListening(userId: appState.currentUserId)
            }
        }
    }
    
    private func createGuest(name: String) {
        Task {
            do {
                _ = try await guestRepo.createGuest(name: name)
                await MainActor.run {
                    HapticManager.shared.success()
                }
            } catch {
                print("Error creating guest: \(error)")
                HapticManager.shared.error()
            }
        }
    }
    
    // Helper View Builder for Alerts
    @ViewBuilder
    private func alerts() -> some View {
        Group {
            if let group = groupToDelete {
                Text("") // Placeholder to attach alert
                    .alert("Delete Group?", isPresented: $showGroupDeleteAlert) {
                        Button("Delete", role: .destructive) {
                            deleteGroup(group)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to delete '\(group.name)'? This action cannot be undone.")
                    }
            }
            
            if let friend = friendToDelete {
                Text("") // Placeholder
                    .alert("Remove Friend?", isPresented: $showFriendDeleteAlert) {
                        Button("Remove", role: .destructive) {
                            removeFriend(friend)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to remove '\(friend.name)'? Transactions involving them might be affected.")
                    }
            }
        }
        .alert(resultTitle, isPresented: $showingResultAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resultMessage)
        }
        .alert("Found Existing Guest", isPresented: $showingMergeAlert) {
            Button("Merge & Add") {
                searchAndSendRequest(username: searchText)
            }
            Button("Just Add") {
                searchAndSendRequest(username: searchText)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let guest = detectedGuest {
                Text("You already have a guest named '\(guest.name)'. Do you want to try and link this new friend request to them?")
            } else {
                Text("Do you want to merge with an existing guest?")
            }
        }
    }

    var groupsList: some View {
        let filteredGroups = appState.groupRepo.groups.filter { group in
            (searchText.isEmpty || group.name.localizedCaseInsensitiveContains(searchText)) &&
            !pendingDeletedGroupIds.contains(group.id ?? "")
        }
        
        return LazyVStack(spacing: 16) {
            // Priority: Group Invitations
            if !appState.groupInvitationRepo.incomingInvitations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GROUP INVITATIONS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppSpacing.margin)
                    
                    ForEach(appState.groupInvitationRepo.incomingInvitations) { invite in
                        HStack(spacing: 12) {
                            // Icon Placeholder
                            Circle()
                                .fill(Color.orange.opacity(0.1))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: "envelope.fill")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Join \"\(invite.groupName)\"")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Invited by you know who") // We might need to fetch sender name
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Accept/Decline Buttons
                            HStack(spacing: 8) {
                                Button(action: {
                                    Task {
                                        do {
                                            try await appState.groupInvitationRepo.declineInvitation(invite)
                                            HapticManager.shared.light()
                                        } catch {
                                            print("Error declining: \(error)")
                                            HapticManager.shared.error()
                                        }
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 32, height: 32)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .clipShape(Circle())
                                }
                                
                                Button(action: {
                                    Task {
                                        do {
                                            try await appState.groupInvitationRepo.acceptInvitation(invite)
                                            HapticManager.shared.success()
                                        } catch {
                                            print("Error accepting: \(error)")
                                            HapticManager.shared.error()
                                        }
                                    }
                                }) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.backgroundPrimary)
                                        .frame(width: 32, height: 32)
                                        .background(Color.functionalSuccess)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, AppSpacing.margin)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, AppSpacing.margin)
                    }
                }
                .padding(.bottom, 8)
            }
            
            // Create New Group Button
            Button(action: { showingAddSheet = true }) {
                HStack(spacing: 12) {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundColor(.secondary)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.secondary)
                        )
                    
                    Text("Create New Group")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.margin)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            ForEach(filteredGroups) { group in
                NavigationLink(destination: GroupDetailView(group: group)) {
                    GroupCardView(group: group)
                        .padding(.horizontal, AppSpacing.margin)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    Button(role: .destructive) {
                        groupToDelete = group
                        showGroupDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            
            if filteredGroups.isEmpty {
                EmptyStateView(
                    icon: "person.3.fill",
                    title: searchText.isEmpty ? "No Groups Yet" : "No Groups Found",
                    message: searchText.isEmpty ? "Create a group to split bills with roommates, trips, or friends." : "Try a different search term."
                )
                .padding(.top, 40)
            }
        }
    }
    
    var friendsList: some View {
        let filteredFriends = appState.friendRepo.friends.filter { friend in
            (searchText.isEmpty || friend.name.localizedCaseInsensitiveContains(searchText) || friend.username.localizedCaseInsensitiveContains(searchText)) &&
            !pendingDeletedFriendIds.contains(friend.id ?? "")
        }
        
        return LazyVStack(spacing: 0) {
            // 0. Incoming Requests Section
            if !appState.friendRequestRepo.incomingRequests.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PENDING REQUESTS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.top, 8)
                    
                    ForEach(appState.friendRequestRepo.incomingRequests) { request in
                        HStack(spacing: 12) {
                            // Avatar Placeholder
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Text(String((request.fromName ?? "?").prefix(1)).uppercased())
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.fromName ?? "Unknown User")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("wants to be friends")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Accept/Decline Buttons
                            HStack(spacing: 8) {
                                Button(action: {
                                    Task {
                                        do {
                                            try await appState.friendRequestRepo.declineRequest(request)
                                            HapticManager.shared.light()
                                        } catch {
                                            print("Error declining: \(error)")
                                            HapticManager.shared.error()
                                        }
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 32, height: 32)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .clipShape(Circle())
                                }
                                
                                Button(action: {
                                    Task {
                                        do {
                                            // Fallback: Create friendship client-side until Cloud Functions are deployed
                                            try await appState.friendRepo.createFriendship(
                                                requestId: request.id ?? "",
                                                fromUser: (
                                                    uid: request.fromUid,
                                                    name: request.fromName ?? "Unknown",
                                                    username: request.fromUsername ?? ""
                                                ),
                                                toUser: (
                                                    uid: appState.currentUserId,
                                                    name: appState.userName,
                                                    username: appState.currentUserUsername,
                                                    email: appState.userEmail
                                                )
                                            )
                                            HapticManager.shared.success()
                                        } catch {
                                            print("Error accepting: \(error)")
                                            HapticManager.shared.error()
                                        }
                                    }
                                }) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.backgroundPrimary)
                                        .frame(width: 32, height: 32)
                                        .background(Color.functionalSuccess)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, AppSpacing.margin)
                        .background(Color(UIColor.secondarySystemBackground)) // Distinct background
                        .cornerRadius(12)
                        .padding(.horizontal, AppSpacing.margin)
                    }
                }
                .padding(.bottom, 16)
            }
            
            ForEach(filteredFriends, id: \.id) { friend in
                NavigationLink(destination: FriendDetailView(friend: friend)) {
                    FriendCardView(friend: friend)
                        .padding(.vertical, 8) // Add some vertical padding for the card
                        .padding(.horizontal, AppSpacing.margin)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    Button(role: .destructive) {
                        friendToDelete = friend
                        showFriendDeleteAlert = true
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            
            // Add Guest Button (Bottom)
            Button(action: { showingAddSheet = true }) {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Circle()
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(.secondary)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.secondary)
                            )
                        
                        Text("Add Guest")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, AppSpacing.margin)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if filteredFriends.isEmpty {
                EmptyStateView(
                     icon: "person.2.fill",
                     title: searchText.isEmpty ? "No Friends Added" : "No Friends Found",
                     message: searchText.isEmpty ? "Add guests or friends to start splitting." : "Try a different search term."
                )
                .padding(.top, 40)
            }
        }
    }
    
    // Deletion Logic
    @State private var groupToDelete: FirestoreModels.Group?
    @State private var showGroupDeleteAlert = false
    
    @State private var friendToDelete: FirestoreModels.Friend?
    @State private var showFriendDeleteAlert = false
    
    // Optimistic Deletion State
    @State private var pendingDeletedGroupIds: Set<String> = []
    @State private var pendingDeletedFriendIds: Set<String> = []

    private func deleteGroup(_ group: FirestoreModels.Group) {
        guard let groupId = group.id else { return }
        
        // Optimistic Update: Hide immediately
        _ = withAnimation {
            pendingDeletedGroupIds.insert(groupId)
        }
        HapticManager.shared.success()
        
        Task {
            do {
                try await appState.groupRepo.deleteGroup(groupId: groupId)
                // Don't remove from pendingDeletedGroupIds immediately. 
                // Let it stay there until the view reloads or standard sync removes it from the source list.
            } catch {
                print("Error deleting group: \(error)")
                await MainActor.run {
                    // Revert optimistic update on error
                    _ = withAnimation {
                        pendingDeletedGroupIds.remove(groupId)
                    }
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func removeFriend(_ friend: FirestoreModels.Friend) {
        guard let friendId = friend.id else { return }
        
        // Optimistic Update: Hide immediately
        _ = withAnimation {
            pendingDeletedFriendIds.insert(friendId)
        }
        HapticManager.shared.success()
        
        Task {
            do {
                try await appState.friendRepo.deleteFriend(friendId: friendId)
                // Same here: Keep in pending until repo updates
            } catch {
                print("Error removing friend: \(error)")
                await MainActor.run {
                     _ = withAnimation {
                        pendingDeletedFriendIds.remove(friendId)
                    }
                     HapticManager.shared.error()
                }
            }
        }
    }

    
    // MARK: - Search & Add Logic
    @State private var isSearching = false
    @State private var showingMergeAlert = false
    @State private var showingResultAlert = false
    @State private var resultMessage = ""
    @State private var resultTitle = ""
    
    @State private var detectedGuest: FirestoreModels.Guest?
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        // 1. Smart Intercept: Check for existing guests
        let matches = guestRepo.findMatchingGuests(friendName: searchText)
        if let match = matches.first {
            detectedGuest = match
            showingMergeAlert = true
            return
        }
        
        // 2. No guest match, proceed to search users
        searchAndSendRequest(username: searchText)
    }
    
    private func searchAndSendRequest(username: String) {
        guard !isSearching else { return }
        isSearching = true
        
        Task {
            do {
                // Check if already friend
                if appState.friendRepo.friends.contains(where: { 
                    $0.username.localizedCaseInsensitiveCompare(username) == .orderedSame 
                }) {
                    await MainActor.run {
                        resultTitle = "Already Friends"
                        resultMessage = "You are already friends with \(username)."
                        showingResultAlert = true
                        isSearching = false
                    }
                    return
                }
                
                // Search for user
                let results = try await appState.friendRepo.searchUsers(username: username)
                
                guard let user = results.first else {
                    await MainActor.run {
                        resultTitle = "User Not Found"
                        resultMessage = "Could not find a user with username '\(username)'."
                        showingResultAlert = true
                        isSearching = false
                    }
                    return
                }
                
                // Optimistic Success: Show alert immediately
                await MainActor.run {
                    resultTitle = "Request Sent"
                    resultMessage = "Friend request sent to \(user.username)."
                    showingResultAlert = true
                    searchText = ""
                    isSearching = false
                    HapticManager.shared.success()
                }
                
                // Perform actual send in background
                Task {
                    do {
                        try await appState.friendRequestRepo.sendFriendRequest(
                            fromUid: appState.currentUserId,
                            fromName: appState.userName,
                            fromUsername: appState.currentUserUsername,
                            toUid: user.id ?? ""
                        )
                    } catch {
                        print("Error sending request in background: \(error)")
                        // Silent fail or retry logic could go here
                    }
                }
                
            } catch {
                await MainActor.run {
                    resultTitle = "Error"
                    resultMessage = "Failed to search: \(error.localizedDescription)"
                    showingResultAlert = true
                    isSearching = false
                    HapticManager.shared.error()
                }
            }
        }
    }
}



