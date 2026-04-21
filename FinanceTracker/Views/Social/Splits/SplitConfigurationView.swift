import SwiftUI
import FirebaseFirestore

enum SplitMode: String, CaseIterable {
    case equal = "Equal"
    case exact = "Exact"
    case percentage = "%"
    case shares = "Shares"
}

struct SplitConfigurationView: View {
    var onSave: ([FirestoreModels.Split], String?) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository

    @StateObject private var viewModel: SplitConfigurationViewModel

    @State private var currentStep = 1
    @State private var showGuestInput = false
    @State private var showGroupWizard = false
    @State private var searchText = ""

    init(transactionAmount: Double, existingSplits: [FirestoreModels.Split], initialGroupId: String? = nil, onSave: @escaping ([FirestoreModels.Split], String?) -> Void) {
        _viewModel = StateObject(wrappedValue: SplitConfigurationViewModel(
            transactionAmount: transactionAmount,
            existingSplits: existingSplits,
            initialGroupId: initialGroupId
        ))
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()
                .ignoresSafeArea(.keyboard, edges: .bottom)

            VStack(spacing: 0) {
                ModalHeader(
                    title: currentStep == 1 ? "Select People" : "Distribution",
                    currentStep: currentStep,
                    totalSteps: 2,
                    onBack: currentStep == 2 ? { withAnimation { currentStep = 1 } } : nil,
                    onClose: { dismiss() }
                )
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, AppSpacing.element)

                if currentStep == 1 {
                    StepOneView.transition(.move(edge: .leading))
                } else {
                    StepTwoView.transition(.move(edge: .trailing))
                }
            }
            .safeAreaInset(edge: .bottom) { stickyActionBar }
        }
        .sheet(isPresented: $showGuestInput) {
            GuestInputView { name in createAndAddGuest(name: name) }
                .presentationDetents([.fraction(0.4)])
        }
        .fullScreenCover(isPresented: $showGroupWizard) {
            GroupCreationWizardView { newGroupId in viewModel.selectedGroupId = newGroupId }
        }
    }

    // MARK: - Step 1: Selection

    private var StepOneView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {

                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search friends or username", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) { _, newValue in
                            Task { try? await appState.friendRepo.searchUsers(username: newValue) }
                        }
                }
                .padding(.horizontal, AppSpacing.element)
                .padding(.vertical, AppSpacing.compact)
                .background(Color.cardBackground)
                .clipShape(Capsule())
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: AppSpacing.compact) {
                    Text("GROUPS")
                        .font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        ScrollViewReader { proxy in
                            HStack(spacing: AppSpacing.element) {
                                Button(action: { showGroupWizard = true }) {
                                    VStack(spacing: 8) {
                                        Circle()
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                            .foregroundColor(.secondary)
                                            .frame(width: 64, height: 64)
                                            .overlay(Image(systemName: "plus").font(.title2).foregroundColor(.secondary))
                                        Text("New").font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                                    }
                                    .frame(width: 70)
                                }

                                ForEach(appState.groupRepo.groups.sorted(by: {
                                    ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
                                }).prefix(5)) { group in
                                    Button(action: {
                                        if viewModel.selectedGroupId == group.id {
                                            viewModel.selectedGroupId = nil
                                            HapticManager.shared.light()
                                        } else {
                                            viewModel.selectGroup(group, allFriends: appState.friendRepo.friends)
                                            HapticManager.shared.medium()
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.GradientTheme.gradient(for: group.color))
                                                    .frame(width: 64, height: 64)
                                                    .shadow(color: Color(hex: group.color).opacity(0.3), radius: 4, x: 0, y: 2)
                                                Image(systemName: group.icon).font(.title3).foregroundColor(.white)
                                            }
                                            .overlay(
                                                Circle().stroke(viewModel.selectedGroupId == group.id ? Color.primary : Color.clear, lineWidth: 3)
                                            )
                                            Text(group.name).font(.caption).fontWeight(.medium).foregroundColor(.primary).lineLimit(1)
                                        }
                                        .frame(width: 70)
                                        .id(group.id)
                                    }
                                }
                            }
                            .padding(.horizontal).padding(.vertical, 8)
                            .onChange(of: viewModel.selectedGroupId) { _, newId in
                                if let newId { withAnimation { proxy.scrollTo(newId, anchor: .center) } }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.compact) {
                    Text("FRIENDS")
                        .font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                        .padding(.horizontal)

                    LazyVStack(spacing: 0) {
                        let filteredFriends = appState.friendRepo.friends.filter {
                            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                        }

                        ForEach(filteredFriends) { friend in
                            Button(action: {
                                HapticManager.shared.light()
                                viewModel.toggleFriendSelection(friend)
                            }) {
                                HStack(spacing: AppSpacing.element) {
                                    ZStack {
                                        let avatarColor = appState.userResolver.resolveAvatarColor(for: friend.id ?? "").map { Color(hex: $0) } ?? Color.random(seed: friend.name)
                                        Circle().fill(avatarColor)
                                            .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                                            .shadow(color: avatarColor.opacity(0.3), radius: 4, x: 0, y: 2)
                                        Text(String(friend.name.prefix(1)).uppercased()).font(.headline).foregroundColor(.white)
                                    }
                                    HStack(spacing: AppSpacing.compact) {
                                        Text(friend.name).font(.body).fontWeight(.medium).foregroundColor(.primary)
                                        if let id = friend.id, userPremiumRepo.isPremium(userId: id) == true {
                                            PremiumBadge(size: .small, overrideBadgeType: userPremiumRepo.badgeType(userId: id))
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: viewModel.selectedFriendIds.contains(friend.id ?? "") ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundColor(viewModel.selectedFriendIds.contains(friend.id ?? "") ? .primary : (colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.3)))
                                }
                                .padding(.vertical, AppSpacing.compact).padding(.horizontal).contentShape(Rectangle())
                            }
                            .onAppear { if let id = friend.id { userPremiumRepo.prefetch(userIds: [id]) } }
                        }

                        if !searchText.isEmpty {
                            let nonFriends = appState.friendRepo.searchResults.filter { user in
                                !appState.friendRepo.friends.contains { $0.id == user.id } &&
                                !viewModel.selectedFriendIds.contains(user.id ?? "")
                            }
                            if !nonFriends.isEmpty {
                                Text("ADD PEOPLE").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                                    .padding(.horizontal).padding(.top, AppSpacing.element)
                                ForEach(nonFriends) { user in
                                    Button(action: { addPendingFriend(user) }) {
                                        HStack(spacing: AppSpacing.element) {
                                            ZStack {
                                                Circle().fill(AppColors.brandPrimary.opacity(0.1)).frame(width: AppSize.avatarList, height: AppSize.avatarList)
                                                Image(systemName: "person.badge.plus").font(.headline).foregroundColor(AppColors.brandPrimary)
                                            }
                                            VStack(alignment: .leading) {
                                                HStack(spacing: AppSpacing.compact) {
                                                    Text(user.name).font(.body).fontWeight(.medium).foregroundColor(.primary)
                                                    if user.isPremium == true {
                                                        PremiumBadge(size: .small, overrideBadgeType: user.badgeType.flatMap { PremiumBadgeType(rawValue: $0) })
                                                    }
                                                }
                                                Text("@" + user.username).font(.caption).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(AppColors.brandPrimary)
                                        }
                                        .padding(.vertical, AppSpacing.compact).padding(.horizontal)
                                    }
                                }
                            }
                        }

                        Button(action: { showGuestInput = true }) {
                            HStack(spacing: AppSpacing.element) {
                                Circle()
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundColor(.secondary)
                                    .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                                    .overlay(Image(systemName: "plus").font(.headline).foregroundColor(.secondary))
                                Text("Add Guest").font(.body).fontWeight(.medium).foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.vertical, AppSpacing.compact).padding(.horizontal)
                        }
                    }
                }

                if !appState.guestRepo.guests.isEmpty || !viewModel.splits.filter({ $0.isGuest }).isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("GUESTS").font(.caption).fontWeight(.bold).foregroundColor(.secondary).padding(.horizontal)
                        LazyVStack(spacing: 0) {
                            ForEach(appState.guestRepo.guests) { guest in
                                Button(action: {
                                    HapticManager.shared.light()
                                    viewModel.toggleGuestSelection(guest)
                                }) {
                                    HStack(spacing: AppSpacing.element) {
                                        ZStack {
                                            Circle().fill(AppColors.functionalExpense.opacity(0.15)).frame(width: AppSize.avatarList, height: AppSize.avatarList)
                                            Image(systemName: "person.fill").font(.headline).foregroundColor(AppColors.functionalExpense)
                                        }
                                        HStack(spacing: AppSpacing.compact) {
                                            Text(guest.name).font(.body).fontWeight(.medium).foregroundColor(.primary)
                                            if viewModel.selectedGuestIds.contains(guest.id ?? "") {
                                                Button(action: { viewModel.toggleGuestSelection(guest) }) {
                                                    Image(systemName: "xmark.circle.fill").font(.caption).foregroundColor(.secondary.opacity(0.5))
                                                }
                                            }
                                            Text("Guest").font(.caption2).foregroundColor(AppColors.functionalExpense).fontWeight(.medium)
                                                .padding(.horizontal, AppSpacing.compact).padding(.vertical, 2)
                                                .background(AppColors.functionalExpense.opacity(0.1)).cornerRadius(AppRadius.badge)
                                        }
                                        Spacer()
                                        Image(systemName: viewModel.selectedGuestIds.contains(guest.id ?? "") ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .foregroundColor(viewModel.selectedGuestIds.contains(guest.id ?? "") ? .primary : (colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.3)))
                                    }
                                    .padding(.vertical, AppSpacing.compact).padding(.horizontal).contentShape(Rectangle())
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
                VStack(spacing: AppSpacing.compact) {
                    Text("Total Amount").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                    Text(symbol + String(format: "%.2f", viewModel.transactionAmount))
                        .font(.system(size: 36, weight: .bold, design: .rounded)).foregroundColor(.primary)

                    if viewModel.splitMode == .equal || viewModel.splitMode == .exact {
                        let totalDistributed = viewModel.splits.reduce(0) { $0 + $1.amount }
                        let remaining = viewModel.transactionAmount - totalDistributed
                        HStack(spacing: 6) {
                            Text("Unassigned:").font(.subheadline).foregroundColor(.secondary)
                            Text(symbol + String(format: "%.2f", max(0, remaining)))
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(abs(remaining) < 0.01 ? Color.functionalSuccess : .orange)
                        }
                    } else if viewModel.splitMode == .percentage {
                        let totalPct = viewModel.percentages.values.reduce(0, +)
                        HStack(spacing: 6) {
                            Text("Total:").font(.subheadline).foregroundColor(.secondary)
                            Text("\(Int(totalPct))%").font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(abs(totalPct - 100) < 1 ? Color.functionalSuccess : .orange)
                        }
                    } else if viewModel.splitMode == .shares {
                        let totalShares = viewModel.shares.values.reduce(0, +)
                        Text("Total Shares: \(totalShares)").font(.subheadline).foregroundColor(.secondary)
                    }
                }
                .padding(.top)

                Picker("Split Mode", selection: Binding(
                    get: { viewModel.splitMode },
                    set: { viewModel.changeSplitMode(to: $0) }
                )) {
                    ForEach(SplitMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                VStack(spacing: AppSpacing.element) {
                    ForEach(viewModel.splits) { split in
                        switch viewModel.splitMode {
                        case .equal, .exact:
                            CustomSplitRow(
                                split: split,
                                mode: viewModel.splitMode,
                                currencySymbol: symbol,
                                onAmountChange: { id, val in viewModel.adjustSplits(manuallyChangedSplitId: id, newValue: val) },
                                onRemove: { viewModel.removeSplit(split) }
                            )
                        case .percentage:
                            PercentageSplitRow(
                                split: split,
                                percentage: Binding(
                                    get: { viewModel.percentages[split.id] ?? 0 },
                                    set: { viewModel.percentages[split.id] = $0; viewModel.recalculateSplits(for: .percentage) }
                                ),
                                currencySymbol: symbol,
                                onRemove: { viewModel.removeSplit(split) }
                            )
                        case .shares:
                            ShareSplitRow(
                                split: split,
                                shareCount: Binding(
                                    get: { viewModel.shares[split.id] ?? 1 },
                                    set: { viewModel.shares[split.id] = $0; viewModel.recalculateSplits(for: .shares) }
                                ),
                                currencySymbol: symbol,
                                onRemove: { viewModel.removeSplit(split) }
                            )
                        }
                    }
                }
                .padding(.horizontal)

                Spacer().frame(height: 100)
            }
        }
    }

    // MARK: - Async Actions (view orchestrates, ViewModel updates)

    private func createAndAddGuest(name: String) {
        Task {
            do {
                let newGuest = try await appState.guestRepo.createGuest(name: name)
                HapticManager.shared.success()
                viewModel.addCreatedGuest(newGuest)
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
                    try await appState.friendRepo.addFriend(
                        currentUserId: appState.currentUserId,
                        currentUserInfo: (appState.currentUserUsername, appState.userName, appState.userEmail),
                        targetUser: user
                    )
                    viewModel.recordFriendRequestSent(userId: uid)
                    HapticManager.shared.success()
                    searchText = ""
                }
            } catch {
                print("Error adding friend: \(error)")
                HapticManager.shared.error()
            }
        }
    }

    private func getSymbol(for currencyCode: String) -> String {
        let locale = NSLocale(localeIdentifier: currencyCode)
        return locale.displayName(forKey: .currencySymbol, value: currencyCode) ?? currencyCode
    }

    // MARK: - Sticky Action Bar

    private var stickyActionBar: some View {
        VStack {
            Button(action: {
                HapticManager.shared.light()
                if currentStep == 1 {
                    withAnimation { currentStep = 2 }
                } else {
                    onSave(viewModel.splits, viewModel.selectedGroupId)
                    dismiss()
                }
            }) {
                Text(currentStep == 1 ? "Next" : "Save Changes")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, AppSpacing.margin)
        .padding(.top, AppSpacing.compact)
        .padding(.bottom, 8)
        .background(Color.backgroundPrimary)
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Reusable Row Components

struct CustomSplitRow: View {
    let split: FirestoreModels.Split
    let mode: SplitMode
    var currencySymbol: String = "$"
    var onAmountChange: (String, Double) -> Void
    var onRemove: () -> Void

    @FocusState private var isFocused: Bool
    @State private var textInput: String = ""

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            SplitAvatar(split: split)
            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(split.name).font(.body).fontWeight(.medium)
                if split.isGuest {
                    Text("Guest").font(.caption2).foregroundColor(AppColors.functionalExpense).fontWeight(.medium)
                        .padding(.horizontal, AppSpacing.compact).padding(.vertical, 2)
                        .background(AppColors.functionalExpense.opacity(0.1)).cornerRadius(AppRadius.badge)
                }
            }
            Spacer()
            if mode == .exact {
                HStack(spacing: 2) {
                    Text(currencySymbol).foregroundColor(.primary).font(.body)
                    TextField("0.00", text: $textInput)
                        .keyboardType(.decimalPad).focused($isFocused)
                        .multilineTextAlignment(.trailing).frame(width: 70)
                        .font(.body.monospacedDigit())
                        .onChange(of: textInput) { _, newValue in if let val = Double(newValue) { onAmountChange(split.id, val) } }
                        .onAppear { textInput = String(format: "%.2f", split.amount) }
                }
                .padding(.vertical, 8).padding(.horizontal, 8)
                .background(Color.cardBackground).cornerRadius(AppRadius.small)
            } else {
                Text(currencySymbol + String(format: "%.2f", split.amount)).font(.body.monospacedDigit()).fontWeight(.semibold)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary.opacity(0.5)).font(.title3)
            }
        }
        .padding().background(Color.cardBackground).cornerRadius(AppRadius.medium)
    }
}

struct PercentageSplitRow: View {
    let split: FirestoreModels.Split
    @Binding var percentage: Double
    var currencySymbol: String = "$"
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            SplitAvatar(split: split)
            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(split.name).font(.body).fontWeight(.medium)
                Text(currencySymbol + String(format: "%.2f", split.amount)).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: AppSpacing.micro) {
                Text("\(Int(percentage))%").font(.headline).fontWeight(.bold).foregroundColor(.blue)
                Slider(value: $percentage, in: 0...100, step: 5).frame(width: 100)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary.opacity(0.5)).font(.title3)
            }
        }
        .padding().background(Color.cardBackground).cornerRadius(AppRadius.medium)
    }
}

struct ShareSplitRow: View {
    let split: FirestoreModels.Split
    @Binding var shareCount: Int
    var currencySymbol: String = "$"
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            SplitAvatar(split: split)
            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(split.name).font(.body).fontWeight(.medium)
                Text(currencySymbol + String(format: "%.2f", split.amount)).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: AppSpacing.compact) {
                Button(action: { if shareCount > 0 { shareCount -= 1 } }) {
                    Image(systemName: "minus.circle.fill").font(.title2).foregroundColor(.secondary)
                }
                Text("\(shareCount)").font(.headline).frame(width: 20).multilineTextAlignment(.center)
                Button(action: { shareCount += 1 }) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.blue)
                }
            }
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary.opacity(0.5)).font(.title3)
            }
        }
        .padding().background(Color.cardBackground).cornerRadius(AppRadius.medium)
    }
}

struct SplitAvatar: View {
    let split: FirestoreModels.Split
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if split.isGuest {
                Circle().fill(Color.themeAccent.opacity(0.15)).frame(width: AppSize.avatarList, height: AppSize.avatarList)
                Image(systemName: "person.fill").font(.headline).foregroundColor(.themeAccent)
            } else {
                let avatarColor = appState.userResolver.resolveAvatarColor(for: split.friendId ?? split.id).map { Color(hex: $0) } ?? Color.random(seed: split.name)
                Circle().fill(avatarColor)
                    .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                    .shadow(color: avatarColor.opacity(0.3), radius: 4, x: 0, y: 2)
                Text(String(split.name.prefix(1)).uppercased()).font(.headline).fontWeight(.bold).foregroundColor(.white)
            }
        }
    }
}
