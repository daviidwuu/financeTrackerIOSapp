import SwiftUI
import FirebaseFirestore

struct EditGroupTransactionWizardView: View {
    let group: FirestoreModels.Group?
    
    // Optional: Only present for editing
    let transactionToEdit: FirestoreModels.GroupTransaction?
    
    // Callback: Returns (Amount, Note, Splits)
    var onSave: (Double, String, [FirestoreModels.Split]) -> Void
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    // State
    @State private var currentStep = 1
    @State private var amount: Double = 0.0
    @State private var amountString: String = ""
    @State private var note: String = ""
    @State private var direction: Edge = .trailing
    @FocusState private var isAmountFocused: Bool
    @State private var isLoadingSplits = false // Fix for race condition
    
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
    
    var body: some View {
        WizardLayout(
            title: stepTitle,
            currentStep: currentStep,
            totalSteps: 4,
            onBack: currentStep > 1 ? {
                direction = .leading
                withAnimation { currentStep -= 1 }
            } : nil,
            onClose: { dismiss() },
            direction: direction
        ) {
            currentStepView
        } actionBar: {
            Button(action: {
                HapticManager.shared.light()
                if currentStep < 4 {
                    // Validation Logic
                    if currentStep == 1 {
                        if let val = Double(amountString) {
                            self.amount = val
                        }
                    }
                    
                    direction = .trailing
                    withAnimation { currentStep += 1 }
                } else {
                    onSave(amount, note, splits)
                    dismiss()
                }
            }) {
                if isLoadingSplits && isEditing {
                     ProgressView()
                         .tint(colorScheme == .dark ? .black : .white)
                } else {
                    Text(currentStep < 4 ? "Next" : (isEditing ? "Save Changes" : "Add Expense"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoadingSplits && isEditing)
        }
        .onAppear {
            initializeData()
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 1: return isEditing ? "Edit Amount" : "Enter Amount"
        case 2: return "Note"
        case 3: return "Select Members"
        case 4: return "Distribution"
        default: return ""
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 1:
            stepOneAmount
        case 2:
            stepTwoNote
        case 3:
            stepThreeMembers
        default:
            stepFourDistribution
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
            // Select everyone by default including self
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
        VStack(spacing: 24) {
            Spacer()
            
            Text(isEditing ? "How much was the total bill?" : "How much did you pay?")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.system(size: 40, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                
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
    
    // MARK: - Step 2: Note
    
    var stepTwoNote: some View {
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
        }
        recalculateSplits(for: splitMode)
    }
    
    func toggleGuest(guest: FirestoreModels.Guest) {
        guard let guestId = guest.id else { return }
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
        }
        recalculateSplits(for: splitMode)
    }
    
    func removeSplit(_ split: FirestoreModels.Split) {
        shares.removeValue(forKey: split.id)
        percentages.removeValue(forKey: split.id)
        lockedSplitIds.remove(split.id)
        splits.removeAll(where: { $0.id == split.id })
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
        ScrollView {
            VStack(spacing: 24) {
                // Total Amount Display
                VStack(spacing: 8) {
                    Text("Total to Split")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text(amount, format: .currency(code: "USD"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
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
                        splitRow(for: split)
                    }
                }
                .padding(.horizontal)
                
                Spacer().frame(height: 100)
            }
        }
    }
    
    @ViewBuilder
    func splitRow(for split: FirestoreModels.Split) -> some View {
        switch splitMode {
        case .equal, .exact:
            CustomSplitRow(
                split: split,
                mode: splitMode,
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
                onRemove: {
                    if let fid = split.friendId {
                        toggleMember(id: fid, name: split.name)
                    }
                }
            )
        }
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
        // If Payer is NOT in splits list (which they aren't, currently), we need to account for them
        // IF the split is "Equal" among everyone including payer.
        // Usually "Split with Group" implies everyone pays their share.
        // So we divide by (Splits Count + 1) for Payer.
        
        let shareAmount = (remainder) / Double(unlockedIndices.count + 1)
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
