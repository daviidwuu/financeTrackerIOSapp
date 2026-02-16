import SwiftUI

struct AddGroupMemberView: View {
    let groupId: String
    var onAddMembers: ([FirestoreModels.Friend], [FirestoreModels.Guest]) -> Void // We can still pass full objects, Parent will extract names
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    // Repositories
    @StateObject private var friendRepo = FriendRepository()
    @StateObject private var guestRepo = GuestRepository()
    
    // State
    @State private var selectedFriendIds: Set<String> = []
    @State private var createdGuests: [FirestoreModels.Guest] = []
    
    // Guest
    @State private var showGuestInput = false
    
    // Search
    @State private var searchText = ""
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                // Header
                ZStack {
                    Text("Add Members")
                        .font(.headline)
                    
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        Spacer()
                    }
                }
                .padding(AppSpacing.margin)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // 0. Search Bar (Pill Shape)
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search friends or username", text: $searchText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: searchText) { _, newValue in
                                    Task {
                                        try? await friendRepo.searchUsers(username: newValue)
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
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
                                let filteredFriends = friendRepo.friends.filter {
                                    searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                                }
                                
                                ForEach(filteredFriends) { friend in
                                    Button(action: { toggleFriendSelection(friend) }) {
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
                                            
                                            Text(friend.name)
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            
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
                                }
                                
                                // Global Search Results
                                if !searchText.isEmpty {
                                    let nonFriends = friendRepo.searchResults.filter { user in
                                        !friendRepo.friends.contains { $0.id == user.id } &&
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
                                            Button(action: { addPendingFriend(user) }) {
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
                                                        Text(user.name)
                                                            .font(.body)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.primary)
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
                            Button(action: { showGuestInput = true }) {
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
                                        
                                        Button(action: { removeGuest(guest) }) {
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
                    .padding(.top)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                   Button(action: {
                       let friends = friendRepo.friends.filter { selectedFriendIds.contains($0.id ?? "") }
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
        .onAppear {
            if !appState.currentUserId.isEmpty {
                friendRepo.startListening(userId: appState.currentUserId)
                guestRepo.startListening(userId: appState.currentUserId)
            }
        }
        .sheet(isPresented: $showGuestInput) {
            GuestInputView { name in
                // Typically we create guest in Repo then add to list
                // Reusing guestRepo logic
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
                    try await friendRepo.addFriend(
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
                let newGuest = try await guestRepo.createGuest(name: name)
                await MainActor.run {
                    HapticManager.shared.success()
                    createdGuests.append(newGuest)
                }
            } catch {
                print("Error creating guest: \(error)")
            }
        }
    }
    
    private func removeGuest(_ guest: FirestoreModels.Guest) {
        createdGuests.removeAll(where: { $0.id == guest.id })
    }
}
