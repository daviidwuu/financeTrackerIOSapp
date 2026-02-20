import SwiftUI

struct GroupCreationWizardView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    // Callback
    var onGroupCreated: ((String) -> Void)?
    var groupToEdit: FirestoreModels.Group?
    
    init(groupToEdit: FirestoreModels.Group? = nil, onGroupCreated: ((String) -> Void)? = nil) {
        self.groupToEdit = groupToEdit
        self.onGroupCreated = onGroupCreated
    }
    
    // Repositories
    // Use shared repo to ensure friends list is up-to-date with SocialDashboard
    var friendRepo: FriendRepository { appState.friendRepo }
    // Using local request for search is fine, but for guests we want shared.
    
    // State
    enum WizardStep {
        case name
        case members
        case styling
    }
    @State private var currentStep: WizardStep = .name
    
    // Data - Step 1
    @State private var groupName = ""
    @FocusState private var isNameFocused: Bool
    
    // Data - Step 2
    @State private var searchText = ""
    
    struct WizardUser: Identifiable, Hashable {
        let id: String
        let name: String
        let isGuest: Bool
    }
    
    @State private var selectedUsers: Set<WizardUser> = []
    @State private var addedGuests: [FirestoreModels.Guest] = [] // Local temporary guests
    @State private var showGuestInput = false
    
    // Data - Step 3
    @State private var selectedColor = AppColors.selectionPalette.first ?? "#007AFF"
    @State private var selectedIcon = "person.3.fill"
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showLeaveGroupDialog = false
    @State private var showDeleteGroupDialog = false
    
    let availableColors = AppColors.selectionPalette
    
    let availableIcons = [
        "person.3.fill", "house.fill", "airplane", "cart.fill", "fork.knife", "gamecontroller.fill",
        "briefcase.fill", "gift.fill", "graduationcap.fill", "heart.fill", "star.fill", "creditcard.fill"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        Button(action: {
                            HapticManager.shared.light()
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text(stepTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Color.clear
                            .frame(width: 44, height: 44)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Header Progress
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Capsule()
                                .fill(getCurrentStepIndex() >= index ? Color.primary : Color.secondary.opacity(0.3))
                                .frame(height: 4)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 24)
                    
                    // Step Content
                    Group {
                        switch currentStep {
                        case .name:
                            nameStep
                                .transition(.move(edge: .leading))
                        case .members:
                            membersStep
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case .styling:
                            stylingStep
                                .transition(.move(edge: .trailing))
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    
                    Spacer()
                }
            }
            .safeAreaInset(edge: .bottom) {
                stickyActionBar
            }
        }
        // Initialize repos
        .onAppear {
            if !appState.currentUserId.isEmpty {
                // friendRepo is now shared via AppState, so listening is handled there.
                // AppState handles guestRepo listening
            }
            
            if let group = groupToEdit {
                populateData(with: group)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if currentStep == .name {
                    isNameFocused = true
                }
            }
        }
        .sheet(isPresented: $showGuestInput) {
            GuestInputView { name in
                createGuest(name: name)
            }
            .presentationDetents([.fraction(0.4)])
        }
        .alert("Error", isPresented: $showError) {
             Button("OK", role: .cancel) { }
        } message: {
             Text(errorMessage)
        }
        .confirmationDialog(
            "Leave Group",
            isPresented: $showLeaveGroupDialog,
            titleVisibility: .visible
        ) {
            Button("Keep my data") {
                leaveGroup(keepData: true)
            }
            Button("Delete my data", role: .destructive) {
                leaveGroup(keepData: false)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your splits and transactions from this group will either be kept as personal records or permanently deleted.")
        }
        .confirmationDialog(
            "Delete Group",
            isPresented: $showDeleteGroupDialog,
            titleVisibility: .visible
        ) {
            Button("Keep Transaction History") {
                confirmGroupDeletion(action: "keep")
            }
            Button("Delete All History", role: .destructive) {
                confirmGroupDeletion(action: "delete")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("What would you like to do with your transaction history?")
        }
        }
    
    // MARK: - Sticky Action Bar
    
    private var stickyActionBar: some View {
        VStack {
            Button(action: {
                withAnimation { nextStep() }
            }) {
                Text(isLastStep ? "Create Group" : "Next")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isStepValid)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Steps
    
    private var nameStep: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 48)
            
            Text("What's the group name?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            TextField("e.g. Summer Trip", text: $groupName)
                .font(AppTypography.titleDisplay)
                .multilineTextAlignment(.center)
                .submitLabel(.next)
                .focused($isNameFocused)
                .onSubmit {
                    if !groupName.isEmpty {
                        withAnimation { nextStep() }
                        isNameFocused = false
                    }
                }
            
            Spacer()
        }
        .padding()
    }
    
    private var membersStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // 1. Search Bar (Pill Shape)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search friends or username", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) { _, newValue in
                            Task {
                                try? await friendRepo.searchUsers(username: newValue.lowercased())
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(Capsule())
                .padding(.horizontal)
                
                // 2. Selected Members Chips (Summary)
                if !selectedUsers.isEmpty || !addedGuests.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selectedUsers), id: \.self) { user in
                                HStack(spacing: 4) {
                                    Text(user.name)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Button(action: { selectedUsers.remove(user) }) {
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.primary.opacity(0.1))
                                .foregroundColor(.primary)
                                .clipShape(Capsule())
                            }
                            
                            ForEach(addedGuests) { guest in
                                HStack(spacing: 4) {
                                    Text(guest.name)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Image(systemName: "person.fill") // Guest Indicator
                                        .font(.caption2)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.primary.opacity(0.1))
                                .foregroundColor(.primary)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                }
                
                // 3. Friends List (LazyVStack)
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
                            let isSelected = selectedUsers.contains { $0.id == friend.id }
                            Button(action: { toggleFriend(friend) }) {
                                HStack(spacing: 16) {
                                    // Avatar
                                    ProfileAvatar(
                                        text: String(friend.name.prefix(1)),
                                        color: Color.random(seed: friend.name),
                                        size: AppSize.avatarList
                                    )
                                    
                                    Text(friend.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    // Checkbox
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundColor(isSelected ? .primary : (colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.3)))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                            }
                        }
                        
                        // 4. Global Search Results (Non-Friends)
                        if !searchText.isEmpty {
                            let nonFriends = friendRepo.searchResults.filter { user in
                                !friendRepo.friends.contains { $0.id == user.id } &&
                                !selectedUsers.contains { $0.id == user.id }
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
                                            ProfileAvatar(
                                                text: String(user.name.prefix(1)),
                                                color: Color.blue.opacity(0.7),
                                                size: AppSize.avatarList
                                            )
                                            
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
                                Circle()
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundColor(.primary)
                                    .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    )
                                
                                Text("Add Guest")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer().frame(height: 100)
            }
        }
    }
    
    private var stylingStep: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Preview
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.GradientTheme.gradient(for: selectedColor))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: selectedIcon)
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color(hex: selectedColor).opacity(0.3), radius: 10, y: 5)
                    
                    Text(groupName)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .padding(.top, 24)
                
                // Colors
                VStack(alignment: .leading, spacing: 16) {
                    Text("Color")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                        ForEach(availableColors, id: \.self) { color in
                            Button(action: {
                                HapticManager.shared.light()
                                selectedColor = color
                            }) {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 4 : 0)
                                            .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                            .opacity(selectedColor == color ? 0.3 : 0)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                
                // Icons
                VStack(alignment: .leading, spacing: 16) {
                    Text("Icon")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: {
                                HapticManager.shared.light()
                                selectedIcon = icon
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color.primary.opacity(0.1) : Color.clear)
                                    
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? .primary : .secondary)
                                }
                                .frame(width: 48, height: 48)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                
                if let group = groupToEdit {
                    let isCreator = group.createdBy == appState.currentUserId
                    
                    Button(role: .destructive, action: {
                        if isCreator {
                            showDeleteGroupDialog = true
                        } else {
                            showLeaveGroupDialog = true
                        }
                    }) {
                        HStack {
                            Image(systemName: isCreator ? "trash" : "rectangle.portrait.and.arrow.right")
                            Text(isCreator ? "Delete Group" : "Leave Group")
                        }
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(AppRadius.small)
                    }
                    .padding(.horizontal)
                }
                
                Spacer().frame(height: 100)
            }
            .padding(.bottom)
        }
    }
    
    // MARK: - Logic
    
    private var stepTitle: String {
        switch currentStep {
        case .name: return groupToEdit != nil ? "Edit Group Name" : "Name Group"
        case .members: return "Add People"
        case .styling: return "Appearance"
        }
    }
    
    private var isLastStep: Bool {
        currentStep == .styling
    }
    
    private var isStepValid: Bool {
        switch currentStep {
        case .name: return !groupName.isEmpty
        case .members: return true // Can have empty members? Sure.
        case .styling: return true
        }
    }
    
    private func getCurrentStepIndex() -> Int {
        switch currentStep {
        case .name: return 0
        case .members: return 1
        case .styling: return 2
        }
    }
    
    private func nextStep() {
        HapticManager.shared.light()
        switch currentStep {
        case .name:
            currentStep = .members
        case .members:
            currentStep = .styling
        case .styling:
            saveGroup()
        }
    }
    
    private func toggleFriend(_ friend: FirestoreModels.Friend) {
        guard let fid = friend.id else { return }
        let user = WizardUser(id: fid, name: friend.name, isGuest: false)
        
        if selectedUsers.contains(user) {
            selectedUsers.remove(user)
        } else {
            selectedUsers.insert(user)
        }
        HapticManager.shared.light()
    }
    
    private func createGuest(name: String) {
        Task {
            do {
                let newGuest = try await appState.guestRepo.createGuest(name: name)
                await MainActor.run {
                    addedGuests.append(newGuest)
                    HapticManager.shared.success()
                }
            } catch {
                print("Error creating guest: \(error)")
            }
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
                        let wUser = WizardUser(id: uid, name: user.name, isGuest: false)
                        selectedUsers.insert(wUser)
                        HapticManager.shared.success()
                        searchText = ""
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to add friend: \(error.localizedDescription)"
                    showError = true
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func saveGroup() {
        guard !groupName.isEmpty else { return }
        
        let memberIds = selectedUsers.map { $0.id } + addedGuests.compactMap { $0.id }
        
        // Calculate Denormalized Names
        var memberNames: [String: String] = [:]
        
        // Preserve existing names if editing
        if let existing = groupToEdit?.memberNames {
            memberNames = existing
        }
        
        // 1. Current User
        if !appState.currentUserId.isEmpty {
             memberNames[appState.currentUserId] = appState.userName
        }
        
        // 2. Friends/Users
        for user in selectedUsers {
            memberNames[user.id] = user.name
        }
        
        // 3. Guests
        for guest in addedGuests {
            if let gid = guest.id {
                memberNames[gid] = guest.name
            }
        }
        
        var groupToSave: FirestoreModels.Group
        
        // Ensure current user is in members list if not already
        var finalMembers = memberIds
        if !appState.currentUserId.isEmpty && !finalMembers.contains(appState.currentUserId) {
            finalMembers.append(appState.currentUserId)
        }
        
        if let existingGroup = groupToEdit {
            groupToSave = existingGroup
            groupToSave.name = groupName
            groupToSave.members = finalMembers
            groupToSave.memberNames = memberNames // ✅ Update names
            groupToSave.icon = selectedIcon
            groupToSave.color = selectedColor
            groupToSave.updatedAt = Date()
        } else {
             groupToSave = FirestoreModels.Group(
                id: nil,
                name: groupName,
                normalizedName: "", // Handled by Repository
                members: finalMembers,
                memberNames: memberNames, // ✅ New Group with Names
                createdBy: appState.currentUserId,
                icon: selectedIcon,
                color: selectedColor,
                createdAt: Date(),
                updatedAt: Date(),
                defaultCurrency: CurrencyManager.shared.mainCurrency
            )
        }
        
        // Instant Feedback: Dismiss immediately
        HapticManager.shared.success()
        dismiss()
        
        Task {
            do {
                if groupToEdit != nil {
                     try await appState.groupRepo.updateGroup(groupToSave)
                } else {
                    let groupId = try await appState.groupRepo.addGroup(groupToSave)
                    await MainActor.run {
                        onGroupCreated?(groupId)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save group: \(error.localizedDescription)"
                    showError = true
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func confirmGroupDeletion(action: String) {
        guard let group = groupToEdit else { return }
        
        // Instant Feedback: Dismiss immediately
        HapticManager.shared.success()
        dismiss()
        
        Task {
            do {
                 try await appState.groupRepo.requestGroupDeletion(group: group)
                 try await appState.groupRepo.submitDeletionAction(group: group, action: action)
            } catch {
                print("Error requesting group deletion: \(error)")
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func leaveGroup(keepData: Bool) {
        guard let groupId = groupToEdit?.id else { return }
        
        Task {
            do {
                try await appState.groupRepo.leaveGroup(groupId: groupId, userId: appState.currentUserId, keepData: keepData)
                await MainActor.run {
                    HapticManager.shared.success()
                    dismiss()
                }
            } catch {
                print("Error leaving group: \(error)")
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func populateData(with group: FirestoreModels.Group) {
        groupName = group.name
        selectedIcon = group.icon
        selectedColor = group.color
        
        let friendIds = group.members.filter { $0 != appState.currentUserId }
        
        var users: Set<WizardUser> = []
        for fid in friendIds {
             let name = group.memberNames?[fid] ?? "Unknown"
             users.insert(WizardUser(id: fid, name: name, isGuest: false))
        }
        selectedUsers = users
    }
}
