import SwiftUI

struct SocialDashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var groupRepo: GroupRepository
    @EnvironmentObject var friendRepo: FriendRepository
    @StateObject private var repo = SocialRepository() // In a real app, might be shared
    @StateObject private var guestRepo = GuestRepository()
    
    @State private var searchText = ""
    @State private var selectedSegment = 0 // 0: Groups, 1: Friends
    @State private var errorState = ErrorState()
    @State private var showingAddSheet = false
    @State private var showArchived = false // ✅ NEW: Toggle archived view
    
    // Navigation Path
    @State private var navigationPath = NavigationPath()
    
    // Enum for stable navigation
    enum SocialDestination: Hashable {
        case group(String)
        case friend(String)
    }
    
    var searchPlaceholder: String {
        switch selectedSegment {
        case 0: return "Search groups..."
        case 1: return "Search friends..."
        case 2: return "Search leaderboard..."
        default: return "Search..."
        }
    }

    init() {
        DebugLogger.log("SocialDashboardView init")
    }

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                Color.backgroundPrimary.ignoresSafeArea()
                    .onTapGesture { HapticManager.shared.light(); 
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }

                List {
                    // Scroll offset tracker + spacer for fixed header
                    ScrollOffsetTracker()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

                    Color.clear.frame(height: 0)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    // Native Segmented Control
                    Section {
                        Picker("Social Options", selection: $selectedSegment) {
                            Text("Groups").tag(0)
                            Text("Friends").tag(1)
                            Text("Leaderboard").tag(2)
                        }
                        .pickerStyle(.segmented)
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        // Search Bar
                        SearchBar(text: $searchText, placeholder: searchPlaceholder, onSearch: performSearch, isLoading: isSearching)
                            .listRowInsets(EdgeInsets(top: 8, leading: AppSpacing.margin, bottom: 8, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    // Content
                    if (selectedSegment == 0 && groupRepo.isLoading) ||
                       (selectedSegment == 1 && friendRepo.isLoading) ||
                       (selectedSegment == 2 && repo.isLoading) {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.top, 40)
                    } else {
                        if selectedSegment == 0 {
                            groupsList
                        } else if selectedSegment == 1 {
                            friendsList
                        } else {
                            leaderboardList
                        }
                    }

                    // Bottom spacer for ad banner
                    Color.clear.frame(height: 70)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(.top, -20)
                .background(alerts())

                // Sticky Adaptive Banner
                VStack {
                    Spacer()
                    AdaptiveBannerView()
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.bottom, AppSpacing.element)
                }
            }
            .overlayHeader(.root(title: "Social"))
            .navigationBarHidden(true)
            .navigationDestination(for: SocialDestination.self) { destination in
                switch destination {
                case .group(let groupId):
                    GroupDetailView(groupId: groupId)
                case .friend(let friendId):
                    FriendDetailContainerView(friendId: friendId)
                }
            }
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
            .alert("Group Deleted", isPresented: Binding(
                get: { groupForDeletionAction != nil },
                set: { _ in groupForDeletionAction = nil }
            )) {
                Button("Keep Transaction History") { HapticManager.shared.light(); 
                    if let group = groupForDeletionAction {
                        if let id = group.id {
                            pendingDeletedGroupIds.insert(id)
                        }
                        // Using the group repo from app state
                        Task {
                            do {
                                try await groupRepo.submitDeletionAction(group: group, action: "keep")
                            } catch {
                                // Handle errors silently for optimistic UI
                            }
                        }
                    }
                }
                Button("Delete All History", role: .destructive) { HapticManager.shared.light(); 
                    if let group = groupForDeletionAction {
                        if let id = group.id {
                            pendingDeletedGroupIds.insert(id)
                        }
                        Task {
                            do {
                                try await groupRepo.submitDeletionAction(group: group, action: "delete")
                            } catch {
                                // Handle errors
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) { HapticManager.shared.light();  }
            } message: {
                if let group = groupForDeletionAction {
                    Text("\(group.name) has been deleted by the creator. What would you like to do with your transaction history?")
                }
            }
        }
        .onChange(of: navigationPath) { _, newPath in
            DebugLogger.log("Navigation path changed. Count: \(newPath.count)")
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
                 
                 // Fetch Leaderboard if needed
                 if repo.leaderboardData.isEmpty {
                     repo.fetchLeaderboard(
                         friends: friendRepo.friends,
                         currentUser: (id: appState.currentUserId, name: appState.userName)
                     )
                 }
            }
        }
        .onDisappear {
            guestRepo.stopListening()
            repo.stopListeningToGlobalBalances()
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
                    .alert("Delete Group?", isPresented: $showGroupDeleteDialog) {
                        Button("Keep Transaction History") { HapticManager.shared.light(); 
                            confirmGroupDeletion(group: group, action: "keep")
                        }
                        Button("Delete All History", role: .destructive) { HapticManager.shared.light(); 
                            confirmGroupDeletion(group: group, action: "delete")
                        }
                        Button("Cancel", role: .cancel) { HapticManager.shared.light();  groupToDelete = nil }
                    } message: {
                        Text("Are you sure you want to delete '\(group.name)'? What would you like to do with your transaction history?")
                    }
            }
            
            if let friend = friendToDelete {
                Text("") // Placeholder
                    .alert("Remove Friend?", isPresented: $showFriendDeleteAlert) {
                        Button("Remove", role: .destructive) { HapticManager.shared.light(); 
                            removeFriend(friend)
                        }
                        Button("Cancel", role: .cancel) { HapticManager.shared.light(); }
                    } message: {
                        Text("Are you sure you want to remove '\(friend.name)'? Transactions involving them might be affected.")
                    }
            }
            
            if let guest = guestToDelete {
                Text("") // Placeholder
                    .alert("Remove Guest?", isPresented: $showGuestDeleteAlert) {
                        Button("Remove", role: .destructive) { HapticManager.shared.light(); 
                            removeGuest(guest)
                        }
                        Button("Cancel", role: .cancel) { HapticManager.shared.light(); }
                    } message: {
                        Text("Are you sure you want to remove '\(guest.name)'? Transactions involving them might be affected.")
                    }
            }
        }
        .alert(resultTitle, isPresented: $showingResultAlert) {
            Button("OK", role: .cancel) { HapticManager.shared.light();  }
        } message: {
            Text(resultMessage)
        }
        .alert("Found Existing Guest", isPresented: $showingMergeAlert) {
            Button("Merge & Add") { HapticManager.shared.light(); 
                if let guest = detectedGuest {
                    searchAndSendRequest(username: searchText, mergeGuestId: guest.id)
                } else {
                    searchAndSendRequest(username: searchText)
                }
            }
            Button("Just Add") { HapticManager.shared.light(); 
                searchAndSendRequest(username: searchText)
            }
            Button("Cancel", role: .cancel) { HapticManager.shared.light();  }
        } message: {
            if let guest = detectedGuest {
                Text("You already have a guest named '\(guest.name)'. Do you want to try and link this new friend request to them?")
            } else {
                Text("Do you want to merge with an existing guest?")
            }
        }
    }

    @ViewBuilder
    var groupsList: some View {
        let allGroups = groupRepo.groups.filter { group in
            let matchesSearch = searchText.isEmpty || group.name.localizedCaseInsensitiveContains(searchText)
            let isNotDeleted = !pendingDeletedGroupIds.contains(group.id ?? "")
            return matchesSearch && isNotDeleted
        }
        
        let pendingDeletionGroups = groupRepo.groups.filter { 
            $0.deletionStatus == "requested" && 
            $0.memberActions?[appState.currentUserId] == "pending" &&
            !pendingDeletedGroupIds.contains($0.id ?? "")
        }
        let activeGroups = allGroups.filter { $0.deletionStatus != "requested" }
        
        Group {
            // Priority 1: Deletion Requests (Action Required)
            if !pendingDeletionGroups.isEmpty {
                Section(header: Text("Action Required").font(.headline).foregroundColor(.functionalError)) {
                    ForEach(pendingDeletionGroups) { group in
                        HStack(spacing: AppSpacing.element) {
                            IconAvatar(systemName: "exclamationmark.triangle.fill", color: AppColors.functionalExpense)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Group deletion requested")
                                    .font(.subheadline)
                                    .foregroundColor(.functionalError)
                            }

                            Spacer()

                            CardChevron()
                        }
                        .appCardStyle()
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColors.functionalExpense.opacity(0.5), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { HapticManager.shared.light(); 
                            groupForDeletionAction = group
                        }
                        .appListRow()
                    }
                }
            }
            
            // Priority 2: Group Invitations
            if !appState.groupInvitationRepo.incomingInvitations.isEmpty {
                Section(header: Text("Group Invitations").font(.headline)) {
                    ForEach(appState.groupInvitationRepo.incomingInvitations) { invite in
                        InvitationCard(invite: invite)
                            .appListRow()
                    }
                }
            }
            
            // Create New Group Button
            DashedAddButton(label: "Create New Group") { HapticManager.shared.light();  showingAddSheet = true }
                .appListRow()

            ForEach(activeGroups) { group in
                GroupCardView(group: group)
                    .contentShape(Rectangle())
                    .onTapGesture { HapticManager.shared.light(); 
                        if let id = group.id {
                            navigationPath.append(SocialDestination.group(id))
                        }
                    }
                    .appListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if group.createdBy == appState.currentUserId {
                            Button(role: .destructive) { HapticManager.shared.light(); 
                                groupToDelete = group
                                showGroupDeleteDialog = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(Color.functionalError)
                        } else {
                            // Leave Logic? Or just hide for now as per previous behavior
                        }
                    }
            }
            
            if allGroups.isEmpty {
                EmptyStateView(
                    icon: "person.3.fill",
                    title: searchText.isEmpty ? "No Groups" : "No Groups Found",
                    message: searchText.isEmpty ? "Create a group to start splitting expenses." : "Try a different search term."
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }

    }
    
    @ViewBuilder
    var friendsList: some View {
        let filteredFriends = friendRepo.friends.filter { friend in
            (searchText.isEmpty || friend.name.localizedCaseInsensitiveContains(searchText) || (friend.username ?? "").localizedCaseInsensitiveContains(searchText)) &&
            !pendingDeletedFriendIds.contains(friend.id ?? "")
        }
        
        let filteredGuests = guestRepo.guests.filter { guest in
            (searchText.isEmpty || guest.name.localizedCaseInsensitiveContains(searchText)) &&
            !pendingDeletedFriendIds.contains(guest.id ?? "")
        }
        
        Group {
            // 0. Incoming Requests Section
            if !appState.friendRequestRepo.incomingRequests.isEmpty {
                Section(header: Text("Pending Requests").font(.headline)) {
                    ForEach(appState.friendRequestRepo.incomingRequests) { request in
                        FriendRequestCard(request: request)
                            .appListRow()
                    }
                }
            }

            // Add Guest Button
            DashedAddButton(label: "Add Guest") { HapticManager.shared.light();  showingAddSheet = true }
                .appListRow()

            ForEach(filteredFriends, id: \.id) { friend in
                FriendCardView(friend: friend)
                    .contentShape(Rectangle())
                    .onTapGesture { HapticManager.shared.light(); 
                        if let id = friend.id {
                            navigationPath.append(SocialDestination.friend(id))
                        }
                    }
                    .appListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { HapticManager.shared.light(); 
                            friendToDelete = friend
                            showFriendDeleteAlert = true
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .tint(.red)
                    }
            }

            ForEach(filteredGuests, id: \.id) { guest in
                GuestCardView(guest: guest)
                    .contentShape(Rectangle())
                    .onTapGesture { HapticManager.shared.light(); 
                        if let id = guest.id {
                            navigationPath.append(SocialDestination.friend(id))
                        }
                    }
                    .appListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { HapticManager.shared.light(); 
                            guestToDelete = guest
                            showGuestDeleteAlert = true
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .tint(.red)
                    }
            }
            
            if filteredFriends.isEmpty && filteredGuests.isEmpty {
                EmptyStateView(
                     icon: "person.2.fill",
                     title: searchText.isEmpty ? "No Friends" : "No Friends or Guests Found",
                     message: searchText.isEmpty ? "Add friends to split bills 1-on-1." : "Try a different search term."
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }
    
    @ViewBuilder
    var leaderboardList: some View {
        let filteredData: [SocialRepository.LeaderboardEntry] = {
            if searchText.isEmpty {
                return repo.leaderboardData
            } else {
                return repo.leaderboardData.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }()
        
        Group {
            if repo.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.top, 40)
            } else if filteredData.isEmpty {
                EmptyStateView(
                    icon: "trophy",
                    title: "Leaderboard",
                    message: searchText.isEmpty ? "Compare your gamification points with friends!" : "No results found."
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .padding(.top, 40)
            } else {
                // 1. Podium for Top 3 (Only if filter is empty to show true leaders)
                if searchText.isEmpty && !filteredData.isEmpty {
                    Section {
                        PodiumView(topUsers: Array(filteredData.prefix(3)))
                            .padding(.top, 20)
                            .frame(maxWidth: .infinity) // Center align
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                
                // 2. List for the rest (or all if filtered)
                let startIndex = (searchText.isEmpty && filteredData.count > 3) ? 3 : 0
                let dataToShow = (searchText.isEmpty && filteredData.count > 3) ? Array(filteredData.dropFirst(3)) : filteredData
                
                ForEach(Array(dataToShow.enumerated()), id: \.element.id) { index, entry in
                    LeaderboardRow(
                        entry: entry,
                        rank: startIndex + index + 1,
                        isCurrentUser: entry.id == appState.currentUserId
                    )
                    .appListRow()
                }
                
                // [NEW] Mock Native Ad
                NativeAdView()
                    .listRowInsets(EdgeInsets(top: 8, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
    }
    
    // Deletion Logic
    @State private var groupToDelete: FirestoreModels.Group?
    @State private var groupForDeletionAction: FirestoreModels.Group?
    @State private var showGroupDeleteDialog = false
    
    @State private var friendToDelete: FirestoreModels.Friend?
    @State private var showFriendDeleteAlert = false
    
    @State private var guestToDelete: FirestoreModels.Guest?
    @State private var showGuestDeleteAlert = false
    
    // Optimistic Deletion State
    @State private var pendingDeletedGroupIds: Set<String> = []
    @State private var pendingDeletedFriendIds: Set<String> = []

    private func confirmGroupDeletion(group: FirestoreModels.Group, action: String) {
        guard group.id != nil else { return }
        
        Task {
            do {
                try await groupRepo.requestGroupDeletion(group: group)
                try await groupRepo.submitDeletionAction(group: group, action: action)
                await MainActor.run {
                    HapticManager.shared.success()
                }
            } catch {
                DebugLogger.log("Error requesting group deletion: \(error)")
                await MainActor.run {
                    HapticManager.shared.error()
                    errorState.show("Failed to delete group: \(error.localizedDescription)")
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
                try await friendRepo.deleteFriend(friendId: friendId)
            } catch {
                DebugLogger.log("Error removing friend: \(error)")
                await MainActor.run {
                     _ = withAnimation {
                        pendingDeletedFriendIds.remove(friendId)
                    }
                     HapticManager.shared.error()
                }
            }
        }
    }

    private func removeGuest(_ guest: FirestoreModels.Guest) {
        guard let guestId = guest.id else { return }
        
        _ = withAnimation {
            pendingDeletedFriendIds.insert(guestId)
        }
        HapticManager.shared.success()
        
        Task {
            do {
                try await guestRepo.deleteGuest(guestId: guestId)
            } catch {
                DebugLogger.log("Error removing guest: \(error)")
                await MainActor.run {
                     _ = withAnimation {
                        pendingDeletedFriendIds.remove(guestId)
                    }
                     HapticManager.shared.error()
                     errorState.show("Failed to remove guest: \(error.localizedDescription)")
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
                if friendRepo.friends.contains(where: { 
                    ($0.username ?? "").localizedCaseInsensitiveCompare(username) == .orderedSame 
                }) {
                    await MainActor.run {
                        resultTitle = "Already Friends"
                        resultMessage = "You are already friends with \(username)."
                        showingResultAlert = true
                        isSearching = false
                    }
                    return
                }
                
                let results = try await friendRepo.searchUsers(username: username)
                
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
                        DebugLogger.log("Error sending request in background: \(error)")
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



// Extracted Subviews for cleaner code
struct InvitationCard: View {
    let invite: FirestoreModels.GroupInvitation
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            IconAvatar(systemName: "envelope.fill", color: .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Join \"\(invite.groupName)\"")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Invited by friend")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(invite.createdAt.timeAgo())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            AcceptDeclineButtons(onAccept: accept, onDecline: decline)
        }
        .appCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(Color.orange, lineWidth: 1)
        )
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
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository
    @EnvironmentObject var friendRepo: FriendRepository
    
    @State private var resolvedFromName: String?

    private var displayName: String {
        // Use resolved name from Firestore fetch if available, otherwise fall back to existing resolution
        let fallback = resolvedFromName ?? request.fromName
        return appState.userResolver.resolveName(for: request.fromUid, fallbackName: fallback)
    }

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            ProfileAvatar(
                text: String(displayName.prefix(1)).uppercased(),
                color: appState.userResolver.resolveAvatarColor(for: request.fromUid).map { Color(hex: $0) } ?? Color.random(seed: displayName),
                size: AppSize.avatarList
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if userPremiumRepo.isPremium(userId: request.fromUid) == true {
                        PremiumBadge(size: .small, overrideBadgeType: userPremiumRepo.badgeType(userId: request.fromUid))
                    }
                }

                Text("wants to be friends")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(request.createdAt.timeAgo())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            AcceptDeclineButtons(onAccept: accept, onDecline: decline)
        }
        .appCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColors.brandPrimary, lineWidth: 1)
        )
        .onAppear {
            userPremiumRepo.prefetch(userIds: [request.fromUid])
            // Fetch sender's profile name if fromName is nil/empty
            if request.fromName == nil || (request.fromName ?? "").isEmpty {
                Task {
                    do {
                        let profile = try await FirebaseManager.shared.getUserProfile(userId: request.fromUid)
                        let name = profile["name"] as? String ?? ""
                        if !name.isEmpty {
                            await MainActor.run {
                                resolvedFromName = name
                            }
                        }
                    } catch {
                        DebugLogger.log("Failed to fetch sender profile for friend request: \(error)")
                    }
                }
            }
        }
    }

    func accept() {
        Task {
            do {
                try await friendRepo.createFriendship(
                    requestId: request.id ?? "",
                    fromUser: (uid: request.fromUid, name: displayName, username: request.fromUsername ?? ""),
                    toUser: (uid: appState.currentUserId, name: appState.userName, username: appState.currentUserUsername, email: appState.userEmail)
                )
                await MainActor.run {
                    HapticManager.shared.success()
                }
            } catch {
                DebugLogger.log("Error accepting friend request: \(error)")
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
        }
    }
    func decline() {
        Task { try? await appState.friendRequestRepo.declineRequest(request); HapticManager.shared.light() }
    }
}
