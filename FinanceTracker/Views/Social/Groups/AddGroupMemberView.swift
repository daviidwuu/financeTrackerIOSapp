import SwiftUI

struct AddGroupMemberView: View {
    let groupId: String
    var onAddMembers: ([FirestoreModels.Friend], [FirestoreModels.Guest]) -> Void // We can still pass full objects, Parent will extract names
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository
    
    // State
    @State private var selectedFriendIds: Set<String> = []
    @State private var createdGuests: [FirestoreModels.Guest] = []
    
    // Guest
    @State private var showGuestInput = false
    
    // Search
    @State private var searchText = ""
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)

                    // 0. Search Bar (Pill Shape)
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search friends or username", text: $searchText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: searchText) { _, newValue in
                                    Task {
                                        try? await appState.friendRepo.searchUsers(username: newValue)
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.cardBackground)
                        .clipShape(Capsule())
                        .padding(.horizontal)
                        
                        // 2. Friends List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("FRIENDS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            LazyVStack(spacing: 0) {
                                let filteredFriends = appState.friendRepo.friends.filter {
                                    searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                                }
                                
                                ForEach(filteredFriends) { friend in
                                    Button(action: { HapticManager.shared.light();  toggleFriendSelection(friend) }) {
                                        HStack(spacing: 16) {
                                            // Avatar
                                            ZStack {
                                                Circle()
                                                    .fill(Color.random(seed: friend.name))
                                                    .frame(width: 48, height: 48)
                                                    .shadow(color: Color.random(seed: friend.name).opacity(0.3), radius: 4, x: 0, y: 2)
                                                
                                                Text(String(friend.name.prefix(1)).uppercased())
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                            }
                                            
                                            HStack(spacing: 8) {
                                                Text(friend.name)
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                
                                                if let id = friend.id, userPremiumRepo.isPremium(userId: id) == true {
                                                    PremiumBadge(size: .small, overrideBadgeType: userPremiumRepo.badgeType(userId: id))
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            // Checkbox
                                            Image(systemName: selectedFriendIds.contains(friend.id ?? "") ? "checkmark.circle.fill" : "circle")
                                                .font(.title2)
                                                .foregroundColor(selectedFriendIds.contains(friend.id ?? "") ? .primary : (colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.3)))
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal)
                                        .contentShape(Rectangle())
                                    }
                                    .onAppear {
                                        if let id = friend.id {
                                            userPremiumRepo.prefetch(userIds: [id])
                                        }
                                    }
                                }
                                
                                // Global Search Results
                                if !searchText.isEmpty {
                                    let nonFriends = appState.friendRepo.searchResults.filter { user in
                                        !appState.friendRepo.friends.contains { $0.id == user.id } &&
                                        !selectedFriendIds.contains(user.id ?? "")
                                    }
                                    
                                    if !nonFriends.isEmpty {
                                        Text("ADD PEOPLE")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                            .padding(.top, 16)
                                        
                                        ForEach(nonFriends) { user in
                                            Button(action: { HapticManager.shared.light();  addPendingFriend(user) }) {
                                                HStack(spacing: 16) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(Color.blue.opacity(0.1))
                                                            .frame(width: 48, height: 48)
                                                        Image(systemName: "person.badge.plus")
                                                            .font(.headline)
                                                            .foregroundColor(.blue)
                                                    }
                                                    
                                                    VStack(alignment: .leading) {
                                                        HStack(spacing: 8) {
                                                            Text(user.name)
                                                                .font(.body)
                                                                .fontWeight(.medium)
                                                                .foregroundColor(.primary)
                                                            
                                                            if user.isPremium == true {
                                                                PremiumBadge(size: .small, overrideBadgeType: user.badgeType.flatMap { PremiumBadgeType(rawValue: $0) })
                                                            }
                                                        }
                                                        Text("@" + user.username)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundColor(.blue)
                                                }
                                                .padding(.vertical, 12)
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                }
                                
                                // Guest Button
                            Button(action: { HapticManager.shared.light();  showGuestInput = true }) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                            .foregroundColor(.secondary)
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "plus")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text("Add Guest")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                            }
                        }
                    }
                    
                    // 3. Guests Added
                        if !createdGuests.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("GUESTS ADDED")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                ForEach(createdGuests) { guest in
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.orange.opacity(0.15))
                                                .frame(width: 48, height: 48)
                                            Image(systemName: "person.fill")
                                                .font(.headline)
                                                .foregroundColor(.orange)
                                        }
                                        
                                        Text(guest.name)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Button(action: { HapticManager.shared.light();  removeGuest(guest) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.secondary.opacity(0.5))
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        Spacer().frame(height: 100)
                    }
                }
            .safeAreaInset(edge: .bottom) {
                VStack {
                   Button(action: { HapticManager.shared.light(); 
                       let friends = appState.friendRepo.friends.filter { selectedFriendIds.contains($0.id ?? "") }
                       onAddMembers(friends, createdGuests)
                       dismiss()
                   }) {
                       Text("Add Selected")
                   }
                   .buttonStyle(PrimaryButtonStyle())
                   .disabled(selectedFriendIds.isEmpty && createdGuests.isEmpty)
                   .opacity((selectedFriendIds.isEmpty && createdGuests.isEmpty) ? 0.6 : 1)
               }
               .padding(.horizontal, AppSpacing.margin)
               .padding(.top, AppSpacing.compact)
               .padding(.bottom, 8)
               .background(Color.backgroundPrimary)
               // Removed ignoresSafeArea(.keyboard) to allow button to move up
            }
        }
        .overlayHeader(.navigation(title: "Add Members", onBack: { dismiss() }, backIcon: "xmark"))
        .sheet(isPresented: $showGuestInput) {
            GuestInputView { name in
                // Typically we create guest in Repo then add to list
                createGuest(name: name)
            }
            .presentationDetents([.fraction(0.4)])
        }
    }
    
    // Logic
    private func toggleFriendSelection(_ friend: FirestoreModels.Friend) {
        guard let fid = friend.id else { return }
        HapticManager.shared.light()
        
        if selectedFriendIds.contains(fid) {
            selectedFriendIds.remove(fid)
        } else {
            selectedFriendIds.insert(fid)
        }
    }
    
    private func addPendingFriend(_ user: FriendRepository.UserSearchResult) {
        guard let uid = user.id else { return }
        Task {
            do {
                if !appState.currentUserId.isEmpty {
                    try await appState.friendRepo.addFriend(
                        currentUserId: appState.currentUserId,
                        currentUserInfo: (appState.currentUserUsername, appState.userName, appState.userEmail),
                        targetUser: user
                    )
                    await MainActor.run {
                        selectedFriendIds.insert(uid)
                        HapticManager.shared.success()
                        searchText = ""
                    }
                }
            } catch {
                HapticManager.shared.error()
            }
        }
    }
    
    private func createGuest(name: String) {
        Task {
            do {
                let newGuest = try await appState.guestRepo.createGuest(name: name)
                await MainActor.run {
                    HapticManager.shared.success()
                    createdGuests.append(newGuest)
                }
            } catch {
                DebugLogger.log("Error creating guest: \(error)")
            }
        }
    }
    
    private func removeGuest(_ guest: FirestoreModels.Guest) {
        createdGuests.removeAll(where: { $0.id == guest.id })
    }
}
