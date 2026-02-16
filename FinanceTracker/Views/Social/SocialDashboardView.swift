import SwiftUI

struct SocialDashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var repo = SocialRepository() // In a real app, might be shared
    @StateObject private var guestRepo = GuestRepository()
    
    @State private var searchText = ""
    @State private var selectedSegment = 0 // 0: Groups, 1: Friends
    @State private var errorState = ErrorState()
    @State private var showingAddSheet = false
    @State private var showArchived = false // ✅ NEW: Toggle archived view
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                VStack(spacing: 0) {
                    // 1. Custom Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Social")
                                .font(AppTypography.titleDisplay)
                                .foregroundColor(.primary)
                            Text("Split bills and track shared expenses")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    
                    ScrollView {
                        VStack(spacing: 4) {
                            // 2. Custom Segmented Control
                            CustomSegmentedControl(selection: $selectedSegment, options: ["Groups", "Friends", "Leaderboard"])
                                .padding(.horizontal, AppSpacing.margin)
                            
                            // 3. Search Bar
                            SearchBar(text: $searchText, onSearch: performSearch, isLoading: isSearching)
                                .padding(.horizontal, AppSpacing.margin)
                                .padding(.vertical, 4)
                            
                            // 4. Content List
                            if (selectedSegment == 0 && appState.groupRepo.isLoading) ||
                               (selectedSegment == 1 && appState.friendRepo.isLoading) ||
                               (selectedSegment == 2 && repo.isLoading) {
                                ProgressView()
                                    .padding(.top, 40)
                            } else {
                                VStack(spacing: 4) {
                                    if selectedSegment == 0 {
                                        groupsList
                                    } else if selectedSegment == 1 {
                                        friendsList
                                    } else {
                                        LeaderboardView(repo: repo, filter: searchText)
                                    }
                                }
                                .padding(.bottom, 100) // Space for bottom area
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .background(alerts())
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
        .onReceive(repo.$errorMessage) { msg in
            if let msg = msg {
                errorState.show(msg)
            }
        }
        .errorBanner(errorState)
        .onAppear {
            if !appState.currentUserId.isEmpty {
                 guestRepo.startListening(userId: appState.currentUserId)
                 // ✅ Start listening to global balances
                 repo.listenToGlobalBalances(currentUserId: appState.currentUserId)
            }
        }
        .onDisappear {
            guestRepo.stopListening()
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
                errorState.show("Failed to create guest")
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
                if let guest = detectedGuest {
                    searchAndSendRequest(username: searchText, mergeGuestId: guest.id)
                } else {
                    searchAndSendRequest(username: searchText)
                }
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
        // ✅ Filter logic: Search + Archive + Soft Delete Pending
        let filteredGroups = appState.groupRepo.groups.filter { group in
            let matchesSearch = searchText.isEmpty || group.name.localizedCaseInsensitiveContains(searchText)
            let isNotDeleted = !pendingDeletedGroupIds.contains(group.id ?? "")
            return matchesSearch && isNotDeleted
        }
        
        return LazyVStack(spacing: 0) {
            // Priority: Group Invitations
            if !appState.groupInvitationRepo.incomingInvitations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("INVITATIONS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppSpacing.margin)
                    
                    ForEach(appState.groupInvitationRepo.incomingInvitations) { invite in
                        InvitationCard(invite: invite)
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
                .padding(AppSpacing.element)
                .padding(.horizontal, AppSpacing.margin)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 8)

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
                        Label("Delete Group", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        groupToDelete = group
                        showGroupDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .padding(.bottom, 8)
            }
            
            if filteredGroups.isEmpty {
                EmptyStateView(
                    icon: "person.3.fill",
                    title: searchText.isEmpty ? "No Groups" : "No Groups Found",
                    message: searchText.isEmpty ? "Create a group to start splitting expenses." : "Try a different search term."
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
                        FriendRequestCard(request: request)
                    }
                }
                .padding(.bottom, 8)
            }
            
            // Add Guest Button (Bottom)
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
                    
                    Text("Add Guest")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(AppSpacing.element)
                .padding(.horizontal, AppSpacing.margin)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 8)
            
            ForEach(filteredFriends, id: \.id) { friend in
                NavigationLink(destination: FriendDetailView(friend: friend)) {
                    FriendCardView(friend: friend)
                        .padding(.horizontal, AppSpacing.margin)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    Button(role: .destructive) {
                        friendToDelete = friend
                        showFriendDeleteAlert = true
                    } label: {
                        Label("Remove Friend", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        friendToDelete = friend
                        showFriendDeleteAlert = true
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .padding(.bottom, 8)
            }
            
            if filteredFriends.isEmpty {
                EmptyStateView(
                     icon: "person.2.fill",
                     title: searchText.isEmpty ? "No Friends" : "No Friends Found",
                     message: searchText.isEmpty ? "Add friends to split bills 1-on-1." : "Try a different search term."
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
            } catch {
                print("Error deleting group: \(error)")
                await MainActor.run {
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
        
        _ = withAnimation {
            pendingDeletedFriendIds.insert(friendId)
        }
        HapticManager.shared.success()
        
        Task {
            do {
                try await appState.friendRepo.deleteFriend(friendId: friendId)
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
        
        let matches = guestRepo.findMatchingGuests(friendName: searchText)
        if let match = matches.first {
            detectedGuest = match
            showingMergeAlert = true
            return
        }
        
        searchAndSendRequest(username: searchText)
    }
    
    private func searchAndSendRequest(username: String, mergeGuestId: String? = nil) {
        guard !isSearching else { return }
        isSearching = true
        
        Task {
            do {
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
                
                await MainActor.run {
                    resultTitle = "Request Sent"
                    resultMessage = "Friend request sent to \(user.username)."
                    if mergeGuestId != nil {
                         resultMessage += " Guest history will be merged once accepted."
                    }
                    showingResultAlert = true
                    searchText = ""
                    isSearching = false
                    HapticManager.shared.success()
                }
                
                Task {
                    do {
                        try await appState.friendRequestRepo.sendFriendRequest(
                            fromUid: appState.currentUserId,
                            fromName: appState.userName,
                            fromUsername: appState.currentUserUsername,
                            toUid: user.id ?? ""
                        )
                        
                        if let guestId = mergeGuestId, let uid = user.id {
                             let friend = FirestoreModels.Friend(
                                 id: uid,
                                 username: user.username,
                                 name: user.name,
                                 email: user.email,
                                 addedAt: Date()
                             )
                             try await repo.mergeGuestToFriend(guestId: guestId, friend: friend, currentUserId: appState.currentUserId)
                        }
                        
                    } catch {
                        print("Error sending request in background: \(error)")
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

// MARK: - Components

struct CustomSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]
    @Namespace private var ns
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = index
                    }
                    HapticManager.shared.selection()
                }) {
                    ZStack {
                        if selection == index {
                            Capsule()
                                .fill(Color.primary)
                                .matchedGeometryEffect(id: "bg", in: ns)
                        }
                        
                        Text(options[index])
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(selection == index ? Color.backgroundPrimary : .secondary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(4)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

// Extracted Subviews for cleaner code
struct InvitationCard: View {
    let invite: FirestoreModels.GroupInvitation
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
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
                
                Text("Invited by friend")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { decline() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Circle())
                }
                
                Button(action: { accept() }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.backgroundPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.functionalSuccess)
                        .clipShape(Circle())
                }
            }
        }
        .padding(AppSpacing.element)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
        .padding(.horizontal, AppSpacing.margin)
    }
    
    func accept() {
        Task { try? await appState.groupInvitationRepo.acceptInvitation(invite); HapticManager.shared.success() }
    }
    func decline() {
        Task { try? await appState.groupInvitationRepo.declineInvitation(invite); HapticManager.shared.light() }
    }
}

struct FriendRequestCard: View {
    let request: FirestoreModels.FriendRequest
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
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
            
            HStack(spacing: 8) {
                Button(action: { decline() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Circle())
                }
                
                Button(action: { accept() }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.backgroundPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.functionalSuccess)
                        .clipShape(Circle())
                }
            }
        }
        .padding(AppSpacing.element)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
        .padding(.horizontal, AppSpacing.margin)
    }
    
    func accept() {
        Task {
            // MVP: Client-side accept
            try? await appState.friendRepo.createFriendship(
                requestId: request.id ?? "",
                fromUser: (uid: request.fromUid, name: request.fromName ?? "Unknown", username: request.fromUsername ?? ""),
                toUser: (uid: appState.currentUserId, name: appState.userName, username: appState.currentUserUsername, email: appState.userEmail)
            )
            HapticManager.shared.success()
        }
    }
    func decline() {
        Task { try? await appState.friendRequestRepo.declineRequest(request); HapticManager.shared.light() }
    }
}
