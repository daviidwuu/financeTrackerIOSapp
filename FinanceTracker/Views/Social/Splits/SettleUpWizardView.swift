import SwiftUI

struct SettleUpWizardView: View {
    let group: FirestoreModels.Group? // Optional
    let preSelectedFriend: FirestoreModels.Friend? // Optional
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @StateObject private var repo = SocialRepository()
    
    @State private var currentStep = 1
    
    // Step 1: Participants
    @State private var payerId: String = ""
    @State private var receiverId: String = ""
    
    // Step 2: Amount
    @State private var amount: String = ""
    @State private var isSubmitting = false
    
    // Step 3 & 4
    @EnvironmentObject var budgetRepo: BudgetRepository
    @EnvironmentObject var transactionRepo: TransactionRepository
    @State private var selectedCategory: FirestoreModels.CategoryBudget?
    @State private var transactionNotes: String = ""
    
    @FocusState private var isAmountFocused: Bool
    @State private var direction: Edge = .trailing
    
    var body: some View {
        WizardLayout(
            title: stepTitle,
            currentStep: currentStep,
            totalSteps: 4,
            onBack: currentStep > 1 ? {
                direction = .leading
                withAnimation { currentStep -= 1 }
                isAmountFocused = currentStep == 2
            } : nil,
            onClose: { dismiss() },
            direction: direction
        ) {
            if currentStep == 1 {
                stepOneView
            } else if currentStep == 2 {
                stepTwoView
            } else if currentStep == 3 {
                stepThreeView
            } else {
                stepFourView
            }
        } actionBar: {
            Button(action: { HapticManager.shared.light(); 
                if currentStep < 4 {
                    HapticManager.shared.light()
                    direction = .trailing
                    withAnimation { currentStep += 1 }
                    if currentStep == 2 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isAmountFocused = true
                        }
                    } else {
                        isAmountFocused = false
                    }
                } else {
                    submit()
                }
            }) {
                Text(currentStep < 4 ? "Next" : "Pay \(amount.isEmpty ? "0.00" : amount)")
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: isSubmitting))
            .disabled(!isValid || isSubmitting)
        }
        .onAppear {
            initializeDefaults()
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 1: return "Who is settling?"
        case 2: return "How much?"
        case 3: return "Category"
        case 4: return "Notes"
        default: return "Settle Up"
        }
    }
    
    private func initializeDefaults() {
        payerId = appState.currentUserId
        
        if let friend = preSelectedFriend, let fid = friend.id {
            receiverId = fid
            Task {
                let balances = await repo.calculateFriendBalance(currentUserId: appState.currentUserId, friendId: fid)
                if let (_, balanceVal) = balances.max(by: { abs($0.value) < abs($1.value) }) {
                    await MainActor.run {
                        if balanceVal > 0.01 { // They owe me
                            payerId = fid
                            receiverId = appState.currentUserId
                            amount = String(format: "%.2f", abs(balanceVal))
                        } else if balanceVal < -0.01 { // I owe them
                            payerId = appState.currentUserId
                            receiverId = fid
                            amount = String(format: "%.2f", abs(balanceVal))
                        }
                    }
                }
                
                // Set default settlement category
                await MainActor.run {
                    if let settlementCat = budgetRepo.budgets.first(where: { $0.category.lowercased() == "settlement" }) {
                        selectedCategory = settlementCat
                    }
                }
            }
        } else if let group = group, let gid = group.id {
            if let firstOther = group.members.first(where: { $0 != appState.currentUserId }) {
                receiverId = firstOther
            }
            Task {
                let balancesByCurrency = await repo.calculateGroupBalances(groupId: gid, currentUserId: appState.currentUserId)
                let instructions = repo.calculateDebtResolution(balances: balancesByCurrency)
                await MainActor.run {
                   if let debtToPay = instructions.first(where: { $0.debtorId == appState.currentUserId }) {
                        payerId = debtToPay.debtorId
                        receiverId = debtToPay.creditorId
                        amount = String(format: "%.2f", debtToPay.amount)
                    } else if let debtToReceive = instructions.first(where: { $0.creditorId == appState.currentUserId }) {
                        payerId = debtToReceive.debtorId
                        receiverId = debtToReceive.creditorId
                        amount = String(format: "%.2f", debtToReceive.amount)
                    }
                    
                    if let settlementCat = budgetRepo.budgets.first(where: { $0.category.lowercased() == "settlement" }) {
                        selectedCategory = settlementCat
                    }
                }
            }
        }
    }
    
    // MARK: - Step 1: Participants
    private var stepOneView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Visualizer
                HStack(spacing: 20) {
                    VStack {
                        ProfileAvatar(text: String(getName(for: payerId).prefix(1)), color: .green, size: 60)
                        Text("Payer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    VStack {
                        ProfileAvatar(text: String(getName(for: receiverId).prefix(1)), color: .blue, size: 60)
                        Text("Receiver")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                Divider()
                
                // Payer Selector
                VStack(alignment: .leading, spacing: 16) {
                    Text("FROM (PAYER)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppSpacing.margin)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if let group = group {
                                ForEach(group.members, id: \.self) { memberId in
                                    participantCard(id: memberId, isSelected: payerId == memberId, isPayer: true)
                                        .onTapGesture { HapticManager.shared.light(); 
                                            payerId = memberId
                                            if receiverId == memberId { receiverId = "" }
                                            HapticManager.shared.light()
                                        }
                                }
                            } else {
                                // Friend Context: Just Me or Friend
                                participantCard(id: appState.currentUserId, isSelected: payerId == appState.currentUserId, isPayer: true)
                                    .onTapGesture { HapticManager.shared.light();  payerId = appState.currentUserId; if receiverId == payerId { receiverId = "" } }
                                
                                if let friend = preSelectedFriend, let fid = friend.id {
                                    participantCard(id: fid, isSelected: payerId == fid, isPayer: true)
                                        .onTapGesture { HapticManager.shared.light();  payerId = fid; if receiverId == payerId { receiverId = "" } }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.vertical, 20)
                    }
                }
                
                // Receiver Selector
                VStack(alignment: .leading, spacing: 16) {
                    Text("TO (RECEIVER)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppSpacing.margin)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if let group = group {
                                ForEach(group.members, id: \.self) { memberId in
                                    participantCard(id: memberId, isSelected: receiverId == memberId, isPayer: false)
                                        .onTapGesture { HapticManager.shared.light(); 
                                            receiverId = memberId
                                            if payerId == memberId { payerId = "" }
                                            HapticManager.shared.light()
                                        }
                                }
                            } else {
                                // Friend Context
                                participantCard(id: appState.currentUserId, isSelected: receiverId == appState.currentUserId, isPayer: false)
                                    .onTapGesture { HapticManager.shared.light();  receiverId = appState.currentUserId; if payerId == receiverId { payerId = "" } }
                                
                                if let friend = preSelectedFriend, let fid = friend.id {
                                    participantCard(id: fid, isSelected: receiverId == fid, isPayer: false)
                                        .onTapGesture { HapticManager.shared.light();  receiverId = fid; if payerId == receiverId { payerId = "" } }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.vertical, 20)
                    }
                }
            }
        }
    }
    
    private func participantCard(id: String, isSelected: Bool, isPayer: Bool) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSelected ? (isPayer ? AppColors.functionalIncome : Color.blue) : Color.cardBackground)
                    .frame(width: 64, height: 64)
                    .shadow(color: isSelected ? (isPayer ? AppColors.functionalIncome.opacity(0.4) : Color.blue.opacity(0.4)) : Color.clear, radius: 8, y: 4)
                
                // Show Name instead of Initial inside circle if selected or always? 
                // Request says "include name underneath the icon", which is already there.
                // Request says "increase padding for icon".
                
                Text(String(getName(for: id).prefix(1)).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(AppSpacing.compact) // Increased padding for icon
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
            
            Text(getName(for: id))
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(width: 90) // Slightly wider to accommodate padding/scale
    }
    
    // MARK: - Step 2: Amount
    private var stepTwoView: some View {
        let isTravelMode = CurrencyManager.shared.isTravelModeEnabled
        let mainCode = CurrencyManager.shared.mainCurrency
        let travelCode = CurrencyManager.shared.travelCurrency
        let symbol = isTravelMode ? getSymbol(for: travelCode) : getSymbol(for: mainCode)
        
        return VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("Enter Amount")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(symbol) // Currency Symbol
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    TextField("0.00", text: $amount)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .foregroundColor(.primary)
                        .focused($isAmountFocused)
                        .fixedSize(horizontal: true, vertical: false) // Grow with text
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.margin)
    }
    
    private func getSymbol(for currencyCode: String) -> String {
        let locale = NSLocale(localeIdentifier: currencyCode)
        return locale.displayName(forKey: .currencySymbol, value: currencyCode) ?? currencyCode
    }
    
    // MARK: - Step 3 & 4
    
    private var stepThreeView: some View {
        VStack(spacing: 8) {
            Text("Select Category")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.horizontal, AppSpacing.margin)
            
            ScrollView {
                VStack(spacing: AppSpacing.element) {
                    if let incomeBudget = budgetRepo.budgets.first(where: { $0.category.lowercased() == "income" }) {
                        Button(action: { HapticManager.shared.light(); 
                            selectedCategory = incomeBudget
                            HapticManager.shared.light()
                        }) {
                            HStack {
                                Image(systemName: incomeBudget.icon)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                                
                                Text(incomeBudget.category)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if selectedCategory?.id == incomeBudget.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: incomeBudget.colorHex))
                            .cornerRadius(AppRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(Color.white.opacity(0.5), lineWidth: selectedCategory?.id == incomeBudget.id ? 4 : 0)
                            )
                        }
                        .padding(.horizontal, AppSpacing.compact)
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: AppSpacing.element) {
                        ForEach(budgetRepo.budgets.filter { $0.category.lowercased() != "income" }) { budget in
                            let remaining = budget.remainingAmount(transactions: transactionRepo.allTransactions)
                            let progress = min(max(1.0 - (remaining / budget.totalAmount), 0.0), 1.0)
                            
                            Button(action: { HapticManager.shared.light(); 
                                selectedCategory = budget
                                HapticManager.shared.light()
                            }) {
                                VStack(spacing: 0) {
                                    HStack(spacing: 8) {
                                        Image(systemName: budget.icon)
                                        .font(.caption)
                                        .foregroundColor(Color(hex: budget.colorHex))
                                        .frame(width: 32, height: 32)
                                        .background(Color(hex: budget.colorHex).opacity(0.2))
                                        .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(budget.category)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 2) {
                                            if budget.type != "income" {
                                                Text("$\(Int(remaining))")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            if selectedCategory?.id == budget.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .padding(AppSpacing.compact)
                                    
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Color(hex: budget.colorHex).opacity(0.1)
                                            Color(hex: budget.colorHex)
                                            .frame(width: geometry.size.width * progress)
                                        }
                                    }
                                    .frame(height: 3)
                                }
                                .background(selectedCategory?.id == budget.id ? Color(hex: budget.colorHex).opacity(0.1) : Color.cardBackground)
                                .cornerRadius(AppRadius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.small)
                                    .stroke(selectedCategory?.id == budget.id ? Color(hex: budget.colorHex) : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.compact)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    
    private var stepFourView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("Notes (Optional)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("e.g. Dinner with Friends", text: $transactionNotes)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .submitLabel(.done)
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.margin)
    }
    
    // MARK: - Helpers
    
    private var isValid: Bool {
        if currentStep == 1 {
            return !payerId.isEmpty && !receiverId.isEmpty && payerId != receiverId
        } else if currentStep == 2 {
            return (Double(amount) ?? 0) > 0
        } else if currentStep == 3 {
            return selectedCategory != nil
        } else {
            return true
        }
    }
    
    private func getName(for id: String) -> String {
        if id == appState.currentUserId { return "You" }
        if let friend = appState.friendRepo.friends.first(where: { $0.id == id }) { return friend.name }
        if let guest = appState.guestRepo.guests.first(where: { $0.id == id }) { return guest.name }
        // Fallback to Group Denormalization
        if let group = group, let name = group.memberNames?[id] { return name }
        
        return "Member"
    }
    
    /// Returns the REAL display name (not "You") for storing in Firestore.
    /// This prevents the "You paid You" bug where "You" gets stored as-is.
    private func getRealName(for id: String) -> String {
        if id == appState.currentUserId { return appState.userName }
        return getName(for: id)  // Other users already get real names
    }
    
    private func submit() {
        guard let amountVal = Double(amount) else { return }
        
        isSubmitting = true
        
        Task {
            do {
                try await SocialTransactionManager.shared.settleUp(
                    payerId: payerId,
                    receiverId: receiverId,
                    groupId: group?.id,
                    amount: amountVal,
                    currency: group?.defaultCurrency ?? CurrencyManager.shared.mainCurrency,
                    payerName: getRealName(for: payerId),
                    receiverName: getRealName(for: receiverId),
                    method: "Payment",
                    note: transactionNotes.isEmpty ? nil : transactionNotes
                )
                HapticManager.shared.success()
                isSubmitting = false
                dismiss()
            } catch {
                DebugLogger.log("Failed to settle up: \(error)")
                HapticManager.shared.error()
                isSubmitting = false
            }
        }
    }
}
