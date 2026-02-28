import SwiftUI
import FirebaseFirestore

struct EditGroupTransactionWizardView: View {
    let group: FirestoreModels.Group?
    let preSelectedFriend: FirestoreModels.Friend?
    
    // Optional: Only present for editing
    let transactionToEdit: FirestoreModels.GroupTransaction?
    
    // Callback: Returns (Amount, Note, Category?, Splits, OriginalAmount?, CurrencyCode?, ExchangeRate?)
    var onSave: (Double, String, FirestoreModels.CategoryBudget?, [FirestoreModels.Split], Double?, String?, Double?) -> Void
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    // State
    @State private var currentStep = 1
    @State private var amount: Double = 0.0
    @State private var amountString: String = ""
    @State private var note: String = ""
    @State private var selectedCategory: FirestoreModels.CategoryBudget?
    @State private var direction: Edge = .trailing
    @FocusState private var isAmountFocused: Bool
    @State private var isLoadingSplits = false // Fix for race condition
    
    @State private var isUsingTravelCurrency = false
    @State private var originalAmount: Double?
    @State private var currencyCode: String?
    @State private var exchangeRate: Double?
    
    // Step 2: Members
    @State private var selectedMemberIds: Set<String> = []
    
    // Step 3: Distribution
    @State private var splitMode: SplitMode = .equal
    @State private var splits: [FirestoreModels.Split] = []
    @State private var shares: [String: Int] = [:]
    @State private var percentages: [String: Double] = [:]
    @State private var lockedSplitIds: Set<String> = []
    
    // Guests
    @State private var addedGuests: [FirestoreModels.Guest] = []
    @State private var showGuestInput = false
    
    // Repos
    @StateObject private var repo = SocialRepository()
    
    var isEditing: Bool { transactionToEdit != nil }
    var isFriendMode: Bool { preSelectedFriend != nil }
    
    // Friend Mode Steps: 1. Amount -> 2. Category -> 3. Note -> 4. Distribution
    // Group Mode Steps: 1. Amount -> 2. Category -> 3. Note -> 4. Members -> 5. Distribution
    var totalSteps: Int { isFriendMode ? 4 : 5 }
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                .ignoresSafeArea()
                
            WizardLayout(
                title: stepTitle,
                currentStep: currentStep,
                totalSteps: totalSteps,
                onBack: currentStep > 1 ? {
                    direction = .leading
                    withAnimation { currentStep -= 1 }
                } : nil,
                onClose: { 
                    print("DEBUG: EditGroupTransactionWizardView onClose called")
                    dismiss() 
                },
                direction: direction
            ) {
                currentStepView
            } actionBar: {
                Button(action: {
                    HapticManager.shared.light()
                    if currentStep < totalSteps {
                        // Validation Logic
                        if currentStep == 1 {
                            syncAmountFromInput()
                        }
                        
                        direction = .trailing
                        withAnimation { currentStep += 1 }
                    } else {
                        print("DEBUG: EditGroupTransactionWizardView onSave called")
                        onSave(amount, note, selectedCategory, splits, originalAmount, currencyCode, exchangeRate)
                        dismiss()
                    }
                }) {
                    if isLoadingSplits && isEditing {
                         ProgressView()
                             .tint(colorScheme == .dark ? .black : .white)
                    } else {
                        Text(currentStep < totalSteps ? "Next" : (isEditing ? "Save Changes" : "Add Expense"))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoadingSplits && isEditing)
            }
        }
        .onAppear {
            initializeData()
        }
    }
    
    private var stepTitle: String {
        if isFriendMode {
            switch currentStep {
            case 1: return isEditing ? "Edit Amount" : "Enter Amount"
            case 2: return "Select Category"
            case 3: return "Note"
            case 4: return "Distribution"
            default: return ""
            }
        } else {
            switch currentStep {
            case 1: return isEditing ? "Edit Amount" : "Enter Amount"
            case 2: return "Select Category"
            case 3: return "Note"
            case 4: return "Select Members"
            case 5: return "Distribution"
            default: return ""
            }
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        if isFriendMode {
            switch currentStep {
            case 1: stepOneAmount
            case 2: stepTwoCategory
            case 3: stepThreeNote
            default: stepFourDistribution
            }
        } else {
            switch currentStep {
            case 1: stepOneAmount
            case 2: stepTwoCategory // Insert Category Step
            case 3: stepThreeNote
            case 4: stepThreeMembers
            default: stepFourDistribution
            }
        }
    }
    
    private func initializeData() {
        if let tx = transactionToEdit {
            // EDIT MODE: Prefill
            self.amount = abs(tx.amount)
            self.amountString = String(format: "%.2f", self.amount)
            self.note = tx.note ?? tx.title
            
            // Load existing splits
            if let originalId = tx.originalTransactionId {
                self.isLoadingSplits = true // Start loading
                Task {
                    do {
                        let existingSplits = try await repo.fetchSplitsForTransaction(transactionId: originalId)
                        
                        await MainActor.run {
                            // Populate members from existing splits
                            var initialSplits: [FirestoreModels.Split] = []
                            for splitRequest in existingSplits {
                                let uid = splitRequest.toUid
                                selectedMemberIds.insert(uid)
                                // Convert SplitRequest to Split model used in wizard
                                let split = FirestoreModels.Split(
                                    id: splitRequest.id ?? UUID().uuidString,
                                    name: splitRequest.toName ?? "Member",
                                    friendId: uid,
                                    amount: splitRequest.amount,
                                    isPaid: splitRequest.status == .paid
                                )
                                initialSplits.append(split)
                            }
                            self.splits = initialSplits
                            
                            // Initialize distribution state
                            for split in initialSplits {
                                shares[split.id] = 1
                                percentages[split.id] = (1.0 / Double(max(1, initialSplits.count))) * 100.0
                            }
                            
                            self.isLoadingSplits = false // Done loading
                        }
                    } catch {
                        print("Error loading splits: \(error)")
                        await MainActor.run { self.isLoadingSplits = false }
                    }
                }
            }
        } else {
            // CREATE MODE: Default to empty
            self.amount = 0.0
            self.amountString = ""
            self.note = ""
            
            // Pre-select Friend if in Friend Mode
            if let friend = preSelectedFriend, let fid = friend.id {
                selectedMemberIds.insert(fid)
                // We need to manually add the split here because we skip Step 3
                let newSplit = FirestoreModels.Split(
                    name: friend.name,
                    friendId: fid,
                    amount: 0.0, // Will be calculated in distribution step
                    isPaid: false
                )
                splits.append(newSplit)
                shares[newSplit.id] = 1
                
                // Trigger recalculation for equal split (50/50 default)
                // But amount is 0 yet, so just setup structure
            }
            
            // Select everyone by default including self if in Group Mode
            if let group = group {
                for memberId in group.members {
                    let name = getMemberName(id: memberId)
                    toggleMember(id: memberId, name: name)
                }
            }
        }
    }
    
    // MARK: - Step 1: Amount
    
    var stepOneAmount: some View {
        let currencyManager = CurrencyManager.shared
        
        return VStack(spacing: 24) {
            Spacer()
            
            Text(isEditing ? "How much was the total bill?" : "How much did you pay?")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if currencyManager.isTravelModeEnabled && currencyManager.mainCurrency != currencyManager.travelCurrency {
                Picker("Currency", selection: $isUsingTravelCurrency) {
                    Text(currencyManager.mainCurrency).tag(false)
                    Text(currencyManager.travelCurrency).tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.margin)
                
                if isUsingTravelCurrency {
                    Text("Converting to approx \(String(format: "%.2f", currencyManager.convertToMain(amount: CurrencyInput.parseOrZero(amountString), from: currencyManager.travelCurrency))) \(currencyManager.mainCurrency)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // Removed explicit symbol to match AddTransactionView style
                TextField("0.00", text: $amountString)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .focused($isAmountFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isAmountFocused = true
                        }
                    }
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }

    private func syncAmountFromInput() {
        let currencyManager = CurrencyManager.shared
        let raw = CurrencyInput.parseOrZero(amountString)
        
        if currencyManager.isTravelModeEnabled,
           currencyManager.mainCurrency != currencyManager.travelCurrency,
           isUsingTravelCurrency {
            amount = currencyManager.convertToMain(amount: raw, from: currencyManager.travelCurrency)
            originalAmount = raw
            currencyCode = currencyManager.travelCurrency
            exchangeRate = currencyManager.exchangeRate
        } else {
            amount = raw
            originalAmount = nil
            currencyCode = nil
            exchangeRate = nil
        }
        
        recalculateSplits(for: splitMode)
    }
    
    // MARK: - Step 2 (Friend Mode): Category
    var stepTwoCategory: some View {
        VStack(spacing: 8) {
            Text("Select Category")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, AppSpacing.margin)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: AppSpacing.element) {
                    ForEach(appState.budgetRepo.budgets.filter { $0.category.lowercased() != "income" }) { budget in
                        Button(action: {
                            selectedCategory = budget
                            HapticManager.shared.light()
                            // Auto-advance? Maybe not, let them click Next
                        }) {
                            VStack(spacing: 0) {
                                HStack(spacing: 8) {
                                    Image(systemName: budget.icon)
                                        .font(.caption)
                                        .foregroundColor(Color(hex: budget.colorHex))
                                        .frame(width: 32, height: 32)
                                        .background(Color(hex: budget.colorHex).opacity(0.1)) // Subtle tint
                                        .clipShape(Circle())
                                    
                                    Text(budget.category)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if selectedCategory?.category == budget.category {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(AppSpacing.compact)
                            }
                            .background(selectedCategory?.category == budget.category ? Color(hex: budget.colorHex).opacity(0.1) : Color(UIColor.secondarySystemBackground))
                            .cornerRadius(AppRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.small)
                                    .stroke(selectedCategory?.category == budget.category ? Color(hex: budget.colorHex) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.compact)
                .padding(.top)
            }
        }
    }
    
    // MARK: - Step 2/3: Note
    
    var stepThreeNote: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("What is this for?")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("e.g. Dinner, Taxi, etc.", text: $note)
                .font(AppTypography.heroInput)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .submitLabel(.done)
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.margin)
    }
    
    // MARK: - Step 3: Members
    
    var stepThreeMembers: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let group = group {
                    Text("GROUP MEMBERS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(group.members, id: \.self) { memberId in
                            memberRow(id: memberId)
                        }
                    }
                } else {
                    Text("No group information available")
                        .padding()
                }
                
                // Guests Section
                if !addedGuests.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GUESTS ADDED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 16)
                        
                        ForEach(addedGuests) { guest in
                            guestRow(guest: guest)
                        }
                    }
                }
                
                // Add Guest Button
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
                
                Spacer().frame(height: 100)
            }
            .padding(.top)
        }
        .sheet(isPresented: $showGuestInput) {
            GuestInputView { name in
                createGuest(name: name)
            }
            .presentationDetents([.fraction(0.4)])
        }
    }
    
    func memberRow(id: String) -> some View {
        let isSelected = selectedMemberIds.contains(id)
        let name = getMemberName(id: id)
        
        return Button(action: { toggleMember(id: id, name: name) }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.random(seed: name))
                        .frame(width: 48, height: 48)
                    Text(String(name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary.opacity(0.3))
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .contentShape(Rectangle())
        }
    }
    
    func guestRow(guest: FirestoreModels.Guest) -> some View {
        let isSelected = selectedMemberIds.contains(guest.id ?? "")
        
        return Button(action: { toggleGuest(guest: guest) }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: guest.avatarColor))
                        .frame(width: 48, height: 48)
                    Image(systemName: "person.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text(guest.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary.opacity(0.3))
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .contentShape(Rectangle())
        }
    }
    
    func toggleMember(id: String, name: String) {
        HapticManager.shared.light()
        if selectedMemberIds.contains(id) {
            selectedMemberIds.remove(id)
            if let splitToRemove = splits.first(where: { $0.friendId == id }) {
                removeSplit(splitToRemove)
            }
        } else {
            selectedMemberIds.insert(id)
            let newSplit = FirestoreModels.Split(
                name: name,
                friendId: id,
                amount: 0.0,
                isPaid: false
            )
            splits.append(newSplit)
            shares[newSplit.id] = 1
            
            // Rebalance percentage
            if splitMode == .percentage {
                let count = Double(splits.count)
                let even = count > 0 ? 100.0 / count : 0
                for split in splits {
                    percentages[split.id] = even
                }
            }
        }
        recalculateSplits(for: splitMode)
    }

    func toggleGuest(guest: FirestoreModels.Guest) {
        guard let guestId = guest.id else { return }
        HapticManager.shared.light()
        if selectedMemberIds.contains(guestId) {
            selectedMemberIds.remove(guestId)
            if let splitToRemove = splits.first(where: { $0.guestId == guestId }) {
                removeSplit(splitToRemove)
            }
        } else {
            selectedMemberIds.insert(guestId)
            let newSplit = FirestoreModels.Split(
                name: guest.name,
                friendId: nil, // Guest doesn't have friendId
                guestId: guestId,
                isGuest: true,
                amount: 0.0,
                isPaid: false
            )
            splits.append(newSplit)
            shares[newSplit.id] = 1
            
            // Rebalance percentage
            if splitMode == .percentage {
                let count = Double(splits.count)
                let even = count > 0 ? 100.0 / count : 0
                for split in splits {
                    percentages[split.id] = even
                }
            }
        }
        recalculateSplits(for: splitMode)
    }
    
    func removeSplit(_ split: FirestoreModels.Split) {
        shares.removeValue(forKey: split.id)
        percentages.removeValue(forKey: split.id)
        lockedSplitIds.remove(split.id)
        splits.removeAll(where: { $0.id == split.id })
        
        // Rebalance percentage
        if splitMode == .percentage {
            let count = Double(splits.count)
            let even = count > 0 ? 100.0 / count : 0
            for split in splits {
                percentages[split.id] = even
            }
        }
    }
    
    func createGuest(name: String) {
        Task {
            do {
                let newGuest = try await appState.guestRepo.createGuest(name: name)
                await MainActor.run {
                    addedGuests.append(newGuest)
                    toggleGuest(guest: newGuest) // Auto-select newly added guest
                    HapticManager.shared.success()
                }
            } catch {
                print("Error creating guest: \(error)")
            }
        }
    }
    
    // MARK: - Step 4: Distribution
    
    var stepFourDistribution: some View {
        let isTravelMode = CurrencyManager.shared.isTravelModeEnabled
        let mainCode = CurrencyManager.shared.mainCurrency
        let travelCode = CurrencyManager.shared.travelCurrency
        let symbol = isTravelMode ? getSymbol(for: travelCode) : getSymbol(for: mainCode)
        
        return ScrollView {
            VStack(spacing: 24) {
                // Total Amount Display
                VStack(spacing: 8) {
                    Text("Total to Split")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.2f", amount))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        
                    if isTravelMode {
                        let mainAmount = CurrencyManager.shared.convertToMain(amount: amount, from: travelCode)
                        Text("≈ \(String(format: "%.2f", mainAmount))")
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
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: splitMode) { _, newMode in
                    withAnimation {
                        recalculateSplits(for: newMode)
                    }
                }
                
                // Splits List
                VStack(spacing: 16) {
                    ForEach(splits) { split in
                        splitRow(for: split, symbol: symbol)
                    }
                }
                .padding(.horizontal)
                
                Spacer().frame(height: 100)
            }
        }
    }
    
    @ViewBuilder
    func splitRow(for split: FirestoreModels.Split, symbol: String) -> some View {
        switch splitMode {
        case .equal, .exact:
            CustomSplitRow(
                split: split,
                mode: splitMode,
                currencySymbol: symbol,
                onAmountChange: { id, val in adjustSplits(manuallyChangedSplitId: id, newValue: val) },
                onRemove: { 
                    if let fid = split.friendId {
                        toggleMember(id: fid, name: split.name)
                    }
                }
            )
        case .percentage:
            PercentageSplitRow(
                split: split,
                percentage: Binding(
                    get: { percentages[split.id] ?? 0 },
                    set: { percentages[split.id] = $0; recalculateSplits(for: .percentage) }
                ),
                currencySymbol: symbol,
                onRemove: {
                    if let fid = split.friendId {
                        toggleMember(id: fid, name: split.name)
                    }
                }
            )
        case .shares:
            ShareSplitRow(
                split: split,
                shareCount: Binding(
                    get: { shares[split.id] ?? 1 },
                    set: { shares[split.id] = $0; recalculateSplits(for: .shares) }
                ),
                currencySymbol: symbol,
                onRemove: {
                    if let fid = split.friendId {
                        toggleMember(id: fid, name: split.name)
                    }
                }
            )
        }
    }
    
    // Helper
    func getSymbol(for currencyCode: String) -> String {
        let locale = NSLocale(localeIdentifier: currencyCode)
        return locale.displayName(forKey: .currencySymbol, value: currencyCode) ?? currencyCode
    }
    
    // Logic (Copied/Adapted from SplitConfigurationView)
    func recalculateSplits(for mode: SplitMode) {
        let totalAmount = self.amount
        switch mode {
        case .equal:
            lockedSplitIds.removeAll()
            distributeRemainder()
            
        case .exact:
            break
            
        case .percentage:
            let _ = percentages.filter { splits.map(\.id).contains($0.key) }.values.reduce(0, +)
            for index in splits.indices {
                let pid = splits[index].id
                let pct = percentages[pid] ?? 0
                splits[index].amount = (pct / 100.0) * totalAmount
            }
            
        case .shares:
             let totalShares = shares.filter { splits.map(\.id).contains($0.key) }.values.reduce(0, +)
             guard totalShares > 0 else { return }
             
             let unitCost = totalAmount / Double(totalShares)
             for index in splits.indices {
                 let pid = splits[index].id
                 let shareCount = shares[pid] ?? 1
                 splits[index].amount = Double(shareCount) * unitCost
             }
        }
    }
    
    func adjustSplits(manuallyChangedSplitId: String, newValue: Double) {
        lockedSplitIds.insert(manuallyChangedSplitId)
        if let index = splits.firstIndex(where: { $0.id == manuallyChangedSplitId }) {
            splits[index].amount = newValue
        }
        distributeRemainder()
    }
    
    func distributeRemainder() {
        let lockedTotal = splits
            .filter { lockedSplitIds.contains($0.id) }
            .reduce(0) { $0 + $1.amount }
        
        let remainder = self.amount - lockedTotal
        let unlockedIndices = splits.indices.filter { !lockedSplitIds.contains(splits[$0].id) }
        
        guard !unlockedIndices.isEmpty else { return }
        
        // Payer + Splits = Total People
        // Logic update: If Payer is ALREADY in splits (Group Mode), don't double count.
        // If Payer is NOT in splits (Friend Mode), add 1.
        let payerIncluded = splits.contains(where: { $0.friendId == appState.currentUserId })
        let divisor = Double(unlockedIndices.count + (payerIncluded ? 0 : 1))
        
        let shareAmount = (remainder) / divisor
        let roundedShare = (shareAmount * 100).rounded() / 100
        
        for index in unlockedIndices {
            splits[index].amount = max(0, roundedShare)
        }
    }
    
    func getMemberName(id: String) -> String {
        if id == appState.currentUserId { return "You" }
        if let friend = appState.friendRepo.friends.first(where: { $0.id == id }) { return friend.name }
        if let group = group, let name = group.memberNames?[id] { return name }
        return "Member"
    }
    
}
