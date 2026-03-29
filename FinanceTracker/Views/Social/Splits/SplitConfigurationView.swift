import SwiftUI
import FirebaseFirestore

enum SplitMode: String, CaseIterable {
    case equal = "Equal"
    case exact = "Exact"
    case percentage = "%"
    case shares = "Shares"
}

struct SplitConfigurationView: View {
    let transactionAmount: Double
    @State var splits: [FirestoreModels.Split]
    var onSave: ([FirestoreModels.Split], String?) -> Void
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository
    
    // Repositories
    @StateObject private var friendRepo = FriendRepository()
    @StateObject private var guestRepo = GuestRepository()
    
    // State
    @State private var currentStep = 1
    @State private var selectedFriendIds: Set<String> = []
    @State private var selectedGuestIds: Set<String> = []
    @State private var lockedSplitIds: Set<String> = []
    @State private var selectedGroupId: String? = nil
    
    // Split Logic
    @State private var splitMode: SplitMode = .equal
    @State private var shares: [String: Int] = [:] // SplitID -> Shares
    @State private var percentages: [String: Double] = [:] // SplitID -> Percentage (0-100)
    
    // Guest
    @State private var showGuestInput = false
    
    // Group Wizard
    @State private var showGroupWizard = false
    
    // Search
    @State private var searchText = ""
    
    init(transactionAmount: Double, existingSplits: [FirestoreModels.Split], initialGroupId: String? = nil, onSave: @escaping ([FirestoreModels.Split], String?) -> Void) {
        self.transactionAmount = transactionAmount
        self._splits = State(initialValue: existingSplits)
        self.onSave = onSave
        
        var initialSelection: Set<String> = []
        var initialGuestSelection: Set<String> = []
        for split in existingSplits {
            if let fid = split.friendId {
                initialSelection.insert(fid)
            }
            if split.isGuest, let gid = split.guestId {
                initialGuestSelection.insert(gid)
            }
        }
        self._selectedFriendIds = State(initialValue: initialSelection)
        self._selectedGuestIds = State(initialValue: initialGuestSelection)
        self._selectedGroupId = State(initialValue: initialGroupId)
    }
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color.black : Color.systemBackground)
                .ignoresSafeArea()
                .ignoresSafeArea(.keyboard, edges: .bottom)
            
            VStack(spacing: 0) {
                // Header
                ModalHeader(
                    title: currentStep == 1 ? "Select People" : "Distribution",
                    currentStep: currentStep,
                    totalSteps: 2,
                    onBack: currentStep == 2 ? {
                        withAnimation { currentStep = 1 }
                    } : nil,
                    onClose: { dismiss() }
                )
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, AppSpacing.element)

                // Content
                if currentStep == 1 {
                    StepOneView
                        .transition(.move(edge: .leading))
                } else {
                    StepTwoView
                        .transition(.move(edge: .trailing))
                }
            }
            .safeAreaInset(edge: .bottom) {
                stickyActionBar
            }
        }
        .onAppear {
            if !appState.currentUserId.isEmpty {
                friendRepo.startListening(userId: appState.currentUserId)
                guestRepo.startListening(userId: appState.currentUserId)
            }
            // Initialize shares/percentages if needed
            for split in splits {
                shares[split.id] = 1
                percentages[split.id] = (1.0 / Double(max(1, splits.count))) * 100.0
            }
        }
        .sheet(isPresented: $showGuestInput) {
            GuestInputView { name in
                createAndAddGuest(name: name)
            }
            .presentationDetents([.fraction(0.4)])
        }
        .fullScreenCover(isPresented: $showGroupWizard) {
            GroupCreationWizardView { newGroupId in
                self.selectedGroupId = newGroupId
            }
        }
    }
    
    // MARK: - Step 1: Selection
    
    private var StepOneView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {

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
                .padding(.horizontal, AppSpacing.element)
                .padding(.vertical, AppSpacing.compact)
                .background(Color.cardBackground)
                .clipShape(Capsule())
                .padding(.horizontal)
                
                // 1. Groups (Horizontal)
                VStack(alignment: .leading, spacing: AppSpacing.compact) {
                    Text("GROUPS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        ScrollViewReader { proxy in
                            HStack(spacing: AppSpacing.element) {
                                // "Create Group" Button
                                Button(action: { showGroupWizard = true }) {
                                    VStack(spacing: 8) {
                                        Circle()
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                            .foregroundColor(.secondary)
                                            .frame(width: 64, height: 64)
                                            .overlay(
                                                Image(systemName: "plus")
                                                    .font(.title2)
                                                    .foregroundColor(.secondary)
                                            )
                                        
                                        Text("New")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 70)
                                }

                                // Recent 5 Groups
                                ForEach(appState.groupRepo.groups.sorted(by: { ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast) }).prefix(5)) { group in
                                    Button(action: { 
                                        if selectedGroupId == group.id {
                                            selectedGroupId = nil
                                            HapticManager.shared.light()
                                        } else {
                                            selectGroup(group) 
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            // Rich Icon Style matching Social Tab
                                            ZStack {
                                                Circle()
                                                    .fill(Color.GradientTheme.gradient(for: group.color))
                                                    .frame(width: 64, height: 64)
                                                    .shadow(color: Color(hex: group.color).opacity(0.3), radius: 4, x: 0, y: 2)
                                                
                                                Image(systemName: group.icon)
                                                    .font(.title3)
                                                    .foregroundColor(.white)
                                            }
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedGroupId == group.id ? Color.primary : Color.clear, lineWidth: 3)
                                            )
                                            
                                            Text(group.name)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 70)
                                        .id(group.id) // Important for ScrollViewReader
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .onChange(of: selectedGroupId) { _, newId in
                                if let newId = newId {
                                    withAnimation {
                                        proxy.scrollTo(newId, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 2. Friends List
                VStack(alignment: .leading, spacing: AppSpacing.compact) {
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
                                HStack(spacing: AppSpacing.element) {
                                    // Avatar - Usage of consistent random color seeding
                                    ZStack {
                                        Circle()
                                            .fill(Color.random(seed: friend.name))
                                            .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                                            // Add shadow for depth consistency with FriendCardView
                                            .shadow(color: Color.random(seed: friend.name).opacity(0.3), radius: 4, x: 0, y: 2)
                                        
                                        Text(String(friend.name.prefix(1)).uppercased())
                                            .font(.headline)
                                            .foregroundColor(.white) // Always white on colorful background
                                    }
                                    
                                    HStack(spacing: AppSpacing.compact) {
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
                                .padding(.vertical, AppSpacing.compact)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                            }
                            .onAppear {
                                if let id = friend.id {
                                    userPremiumRepo.prefetch(userIds: [id])
                                }
                            }
                        }

                        // Global Search Results (Non-Friends)
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
                                    .padding(.top, AppSpacing.element)

                                ForEach(nonFriends) { user in
                                    Button(action: { addPendingFriend(user) }) {
                                        HStack(spacing: AppSpacing.element) {
                                            ZStack {
                                                Circle()
                                                    .fill(AppColors.brandPrimary.opacity(0.1))
                                                    .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                                                Image(systemName: "person.badge.plus")
                                                    .font(.headline)
                                                    .foregroundColor(AppColors.brandPrimary)
                                            }

                                            VStack(alignment: .leading) {
                                                HStack(spacing: AppSpacing.compact) {
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
                                                .foregroundColor(AppColors.brandPrimary)
                                        }
                                        .padding(.vertical, AppSpacing.compact) // TODO: add DS token for 12pt inset padding
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        
                        // Guest Button
                        Button(action: { showGuestInput = true }) {
                            HStack(spacing: AppSpacing.element) {
                                Circle()
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundColor(.secondary)
                                    .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                    )
                                
                                Text("Add Guest")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.vertical, AppSpacing.compact)
                            .padding(.horizontal)
                        }
                    }
                }

                // 3. Guests Section
                if !guestRepo.guests.isEmpty || !splits.filter({ $0.isGuest }).isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("GUESTS")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        LazyVStack(spacing: 0) {
                            // Show all guests from repo with toggle
                            ForEach(guestRepo.guests) { guest in
                                Button(action: { toggleGuestSelection(guest) }) {
                                    HStack(spacing: AppSpacing.element) {
                                        ZStack {
                                            Circle()
                                                .fill(AppColors.functionalExpense.opacity(0.15))
                                                .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                                            Image(systemName: "person.fill")
                                                .font(.headline)
                                                .foregroundColor(AppColors.functionalExpense)
                                        }

                                        HStack(spacing: AppSpacing.compact) {
                                            Text(guest.name)
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)

                                            if selectedGuestIds.contains(guest.id ?? "") {
                                                Button(action: {
                                                    if let gid = guest.id {
                                                        toggleGuestSelection(guest)
                                                    }
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary.opacity(0.5))
                                                }
                                            }

                                            Text("Guest")
                                                .font(.caption2)
                                                .foregroundColor(AppColors.functionalExpense)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, AppSpacing.compact)
                                                .padding(.vertical, 2)
                                                .background(AppColors.functionalExpense.opacity(0.1))
                                                .cornerRadius(AppRadius.badge)
                                        }

                                        Spacer()

                                        // Checkbox
                                        Image(systemName: selectedGuestIds.contains(guest.id ?? "") ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .foregroundColor(selectedGuestIds.contains(guest.id ?? "") ? .primary : (colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.3)))
                                    }
                                    .padding(.vertical, AppSpacing.compact) // TODO: add DS token for 12pt inset padding
                                    .padding(.horizontal)
                                    .contentShape(Rectangle())
                                }
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 100)
            }
            .padding(.top)
        }
    }
    
    // MARK: - Step 2: Distribution
    
    private var StepTwoView: some View {
        let symbol = getSymbol(for: CurrencyManager.shared.mainCurrency)
        
        return ScrollView {
            VStack(spacing: AppSpacing.large) {
                // Total Owed Card
                VStack(spacing: AppSpacing.compact) {
                    Text("Total Amount")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text(symbol + String(format: "%.2f", transactionAmount))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    // Remainder logic dependent on mode
                    if splitMode == .equal || splitMode == .exact {
                        let totalDistributed = splits.reduce(0) { $0 + $1.amount }
                        let remaining = transactionAmount - totalDistributed
                        HStack(spacing: 6) {
                            Text("Unassigned:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(symbol + String(format: "%.2f", max(0, remaining)))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(abs(remaining) < 0.01 ? Color.functionalSuccess : .orange)
                        }
                    } else if splitMode == .percentage {
                        let totalPct = percentages.values.reduce(0, +)
                        HStack(spacing: 6) {
                            Text("Total:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(Int(totalPct))%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(abs(totalPct - 100) < 1 ? Color.functionalSuccess : .orange)
                        }
                    } else if splitMode == .shares {
                        let totalShares = shares.values.reduce(0, +)
                        Text("Total Shares: \(totalShares)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)
                
                // Mode Selector
                Picker("Split Mode", selection: $splitMode) {
                    ForEach(SplitMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: splitMode) { _, newMode in
                    recalculateSplits(for: newMode)
                }
                
                // Splits List
                VStack(spacing: AppSpacing.element) {
                    ForEach(splits) { split in
                        switch splitMode {
                        case .equal, .exact:
                            CustomSplitRow(
                                split: split,
                                mode: splitMode,
                                currencySymbol: symbol,
                                onAmountChange: { id, val in adjustSplits(manuallyChangedSplitId: id, newValue: val) },
                                onRemove: { removeSplit(split) }
                            )
                        case .percentage:
                            PercentageSplitRow(
                                split: split,
                                percentage: Binding(
                                    get: { percentages[split.id] ?? 0 },
                                    set: { percentages[split.id] = $0; recalculateSplits(for: .percentage) }
                                ),
                                currencySymbol: symbol,
                                onRemove: { removeSplit(split) }
                            )
                        case .shares:
                            ShareSplitRow(
                                split: split,
                                shareCount: Binding(
                                    get: { shares[split.id] ?? 1 },
                                    set: { shares[split.id] = $0; recalculateSplits(for: .shares) }
                                ),
                                currencySymbol: symbol,
                                onRemove: { removeSplit(split) }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer().frame(height: 100)
            }
        }
    }
    
    private func getSymbol(for currencyCode: String) -> String {
        let locale = NSLocale(localeIdentifier: currencyCode)
        return locale.displayName(forKey: .currencySymbol, value: currencyCode) ?? currencyCode
    }
    
    // MARK: - Logic
    
    private func recalculateSplits(for mode: SplitMode) {
        switch mode {
        case .equal:
            lockedSplitIds.removeAll()
            distributeRemainder()
            
        case .exact:
            // Keep current amounts, but allow manual edit
            break
            
        case .percentage:
            let _ = percentages.filter { splits.map(\.id).contains($0.key) }.values.reduce(0, +)
            for index in splits.indices {
                let pid = splits[index].id
                let pct = percentages[pid] ?? 0
                splits[index].amount = (pct / 100.0) * transactionAmount
            }
            
        case .shares:
             let totalShares = shares.filter { splits.map(\.id).contains($0.key) }.values.reduce(0, +)
             guard totalShares > 0 else { return }
             
             let unitCost = transactionAmount / Double(totalShares)
             for index in splits.indices {
                 let pid = splits[index].id
                 let shareCount = shares[pid] ?? 1
                 splits[index].amount = Double(shareCount) * unitCost
             }
        }
    }
    
    private func toggleFriendSelection(_ friend: FirestoreModels.Friend) {
        guard let friendId = friend.id else { return }
        HapticManager.shared.light()
        
        if selectedFriendIds.contains(friendId) {
            selectedFriendIds.remove(friendId)
            splits.removeAll(where: { $0.friendId == friendId })
            shares.removeValue(forKey: friendId) // Technically need to use split ID map
        } else {
            selectedFriendIds.insert(friendId)
            let newSplit = FirestoreModels.Split(
                name: friend.name,
                friendId: friendId,
                username: friend.username,
                amount: 0.0
            )
            splits.append(newSplit)
            shares[newSplit.id] = 1
            percentages[newSplit.id] = 0 // Will rebalance
        }
        
        // Auto-rebalance percentages if adding new person
        if splitMode == .percentage {
            let count = Double(splits.count)
            let even = 100.0 / count
            for split in splits {
                percentages[split.id] = even
            }
        }
        
        recalculateSplits(for: splitMode)
    }
    
    private func selectGroup(_ group: FirestoreModels.Group) {
        selectedGroupId = group.id
        HapticManager.shared.medium()
        
        let friendsToAdd = friendRepo.friends.filter { friend in
            guard let fid = friend.id else { return false }
            return group.members.contains(fid)
        }
        
        for friend in friendsToAdd {
            guard let fid = friend.id else { continue }
            if !selectedFriendIds.contains(fid) {
                selectedFriendIds.insert(fid)
                let newSplit = FirestoreModels.Split(
                    name: friend.name,
                    friendId: fid,
                    username: friend.username,
                    amount: 0.0
                )
                splits.append(newSplit)
                shares[newSplit.id] = 1
            }
        }
        
        if splitMode == .percentage {
            let count = Double(splits.count)
            let even = 100.0 / count
            for split in splits {
                percentages[split.id] = even
            }
        }
        
        recalculateSplits(for: splitMode)
    }
    
    private func createAndAddGuest(name: String) {
        Task {
            do {
                let newGuest = try await guestRepo.createGuest(name: name)
                await MainActor.run {
                    HapticManager.shared.success()
                    if let gid = newGuest.id {
                        selectedGuestIds.insert(gid)
                    }
                    let newSplit = FirestoreModels.Split(
                        name: newGuest.name,
                        guestId: newGuest.id,
                        isGuest: true,
                        amount: 0.0
                    )
                    splits.append(newSplit)
                    shares[newSplit.id] = 1
                    
                    if splitMode == .percentage {
                         let count = Double(splits.count)
                         let even = 100.0 / count
                         for split in splits {
                             percentages[split.id] = even
                         }
                    }
                    
                    recalculateSplits(for: splitMode)
                }
            } catch {
                print("Error creating guest: \(error)")
            }
        }
    }
    
    private func removeSplit(_ split: FirestoreModels.Split) {
        if let fid = split.friendId {
            selectedFriendIds.remove(fid)
        }
        if let gid = split.guestId {
            selectedGuestIds.remove(gid)
        }
        splits.removeAll(where: { $0.id == split.id })
        lockedSplitIds.remove(split.id)
        shares.removeValue(forKey: split.id)
        percentages.removeValue(forKey: split.id)

        recalculateSplits(for: splitMode)
    }

    private func toggleGuestSelection(_ guest: FirestoreModels.Guest) {
        guard let guestId = guest.id else { return }
        HapticManager.shared.light()

        if selectedGuestIds.contains(guestId) {
            selectedGuestIds.remove(guestId)
            splits.removeAll(where: { $0.guestId == guestId })
        } else {
            selectedGuestIds.insert(guestId)
            let newSplit = FirestoreModels.Split(
                name: guest.name,
                guestId: guestId,
                isGuest: true,
                amount: 0.0
            )
            splits.append(newSplit)
            shares[newSplit.id] = 1
            percentages[newSplit.id] = 0
        }

        if splitMode == .percentage {
            let count = Double(splits.count)
            let even = 100.0 / max(1, count)
            for split in splits {
                percentages[split.id] = even
            }
        }

        recalculateSplits(for: splitMode)
    }
    
    private func adjustSplits(manuallyChangedSplitId: String, newValue: Double) {
        // Only for Exact Mode or Equal Mode override
        lockedSplitIds.insert(manuallyChangedSplitId)
        if let index = splits.firstIndex(where: { $0.id == manuallyChangedSplitId }) {
            splits[index].amount = newValue
        }
        distributeRemainder()
    }
    
    private func distributeRemainder() {
        let lockedTotal = splits
            .filter { lockedSplitIds.contains($0.id) }
            .reduce(0) { $0 + $1.amount }
        
        let remainder = transactionAmount - lockedTotal
        let unlockedIndices = splits.indices.filter { !lockedSplitIds.contains(splits[$0].id) }
        
        guard !unlockedIndices.isEmpty else { return }
        
        // Include user in split count? Logic assumes 'splits' includes everyone involved.
        // Actually, typically 'splits' implies people OTHER than payer if logic is 'I paid, you owe'.
        // But for 'Split Bill', usually we define who participated.
        // In this app, 'splits' seems to be ONLY other people currently?
        // Wait, if I pay $100 and split equally with Bob, Bob owes $50.
        // We need to know if Current User is INCLUDED in the split.
        // Current logic: splits is just a list of debt requests.
        // So Remainder / (Count + 1). (See original file line 549: `Double(unlockedIndices.count + 1)`)
        
        let shareAmount = (remainder) / Double(unlockedIndices.count + 1)
        let roundedShare = (shareAmount * 100).rounded() / 100
        
        for index in unlockedIndices {
            splits[index].amount = max(0, roundedShare)
        }
    }
    
    // MARK: - API
    
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
                print("Error adding friend: \(error)")
                HapticManager.shared.error()
            }
        }
    }
    
    // MARK: - Sticky Action Bar
    
    private var stickyActionBar: some View {
        VStack {
            Button(action: {
                HapticManager.shared.light()
                if currentStep == 1 {
                    withAnimation { currentStep = 2 }
                } else {
                    onSave(splits, selectedGroupId)
                    dismiss()
                }
            }) {
                Text(currentStep == 1 ? "Next" : "Save Changes")
            }
            .buttonStyle(PrimaryButtonStyle())
            // Removed .disabled check to allow zero-person split (user pays 100%, or clearing splits)
        }
        .padding(.horizontal, AppSpacing.margin)
        .padding(.top, AppSpacing.compact)
        .padding(.bottom, 8)
        .background(Color.backgroundPrimary)
        .ignoresSafeArea(.keyboard) 
    }
}

// MARK: - Components

struct CustomSplitRow: View {
    let split: FirestoreModels.Split
    let mode: SplitMode
    var currencySymbol: String = "$" // Default
    var onAmountChange: (String, Double) -> Void
    var onRemove: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var textInput: String = ""
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            SplitAvatar(name: split.name, isGuest: split.isGuest)

            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(split.name)
                    .font(.body)
                    .fontWeight(.medium)

                if split.isGuest {
                    Text("Guest")
                        .font(.caption2)
                        .foregroundColor(AppColors.functionalExpense)
                        .fontWeight(.medium)
                        .padding(.horizontal, AppSpacing.compact)
                        .padding(.vertical, 2)
                        .background(AppColors.functionalExpense.opacity(0.1))
                        .cornerRadius(AppRadius.badge)
                }
            }
            
            Spacer()
            
            if mode == .exact {
                HStack(spacing: 2) {
                    Text(currencySymbol)
                        .foregroundColor(.primary)
                        .font(.body)
                    
                    TextField("0.00", text: $textInput)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .font(.body.monospacedDigit())
                        .onChange(of: textInput) { _, newValue in
                            if let val = Double(newValue) {
                                onAmountChange(split.id, val)
                            }
                        }
                        .onAppear {
                            textInput = String(format: "%.2f", split.amount)
                        }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(Color.cardBackground)
                .cornerRadius(AppRadius.small)
            } else {
                Text(currencySymbol + String(format: "%.2f", split.amount))
                    .font(.body.monospacedDigit())
                    .fontWeight(.semibold)
            }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.5))
                    .font(.title3)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }
}

struct PercentageSplitRow: View {
    let split: FirestoreModels.Split
    @Binding var percentage: Double
    var currencySymbol: String = "$" // Default
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            SplitAvatar(name: split.name, isGuest: split.isGuest)

            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(split.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(currencySymbol + String(format: "%.2f", split.amount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: AppSpacing.micro) {
                Text("\(Int(percentage))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Slider(value: $percentage, in: 0...100, step: 5)
                    .frame(width: 100)
            }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.5))
                    .font(.title3)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }
}

struct ShareSplitRow: View {
    let split: FirestoreModels.Split
    @Binding var shareCount: Int
    var currencySymbol: String = "$" // Default
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            SplitAvatar(name: split.name, isGuest: split.isGuest)

            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(split.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(currencySymbol + String(format: "%.2f", split.amount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: AppSpacing.compact) {
                Button(action: { if shareCount > 0 { shareCount -= 1 } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                Text("\(shareCount)")
                    .font(.headline)
                    .frame(width: 20)
                    .multilineTextAlignment(.center)
                
                Button(action: { shareCount += 1 }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.5))
                    .font(.title3)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }
}

struct SplitAvatar: View {
    let name: String
    let isGuest: Bool
    
    var body: some View {
        ZStack {
            if isGuest {
                Circle()
                    .fill(Color.themeAccent.opacity(0.15))
                    .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                Image(systemName: "person.fill")
                    .font(.headline)
                    .foregroundColor(.themeAccent)
            } else {
                Circle()
                    .fill(Color.random(seed: name))
                    .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                    .shadow(color: Color.random(seed: name).opacity(0.3), radius: 4, x: 0, y: 2)
                
                Text(String(name.prefix(1)).uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
    }
}
