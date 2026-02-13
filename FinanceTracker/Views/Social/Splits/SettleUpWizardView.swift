import SwiftUI

struct SettleUpWizardView: View {
    let group: FirestoreModels.Group? // Optional, can be used for pre-filtering or group context
    let preSelectedFriend: FirestoreModels.Friend? // Entry from friend detail
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @StateObject private var repo = SocialRepository()
    
    @State private var currentStep = 1
    @State private var direction: Edge = .trailing
    
    // Step 1: Participants
    @State private var payerId: String = ""
    @State private var receiverId: String = ""
    
    // Step 2: Amount
    @State private var amount: String = ""
    @State private var isSubmitting = false
    
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                ModalHeader(
                    title: stepTitle,
                    currentStep: currentStep,
                    totalSteps: 2,
                    onBack: currentStep > 1 ? {
                        withAnimation { currentStep -= 1 }
                    } : nil,
                    onClose: { dismiss() }
                )
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, 16)
                
                // Content
                TabView(selection: $currentStep) {
                    stepOneView.tag(1)
                    stepTwoView.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                Spacer()
                
                // Sticky Action Bar
                stickyActionBar
            }
        }
        .onAppear {
            initializeDefaults()
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 1: return "Who is settling?"
        case 2: return "Amount & Method"
        default: return "Settle Up"
        }
    }
    
    private func initializeDefaults() {
        // Initial Default: Me paying someone
        payerId = appState.currentUserId
        
        if let friend = preSelectedFriend, let fid = friend.id {
            receiverId = fid
            
            // Check real balance to see who owes whom
            Task {
                let balances = await repo.calculateFriendBalance(currentUserId: appState.currentUserId, friendId: fid)
                // Pick the currency with the absolute largest balance for the default view
                if let (_, balanceVal) = balances.max(by: { abs($0.value) < abs($1.value) }) {
                    await MainActor.run {
                        if balanceVal > 0.01 { // They owe me (Positive)
                            payerId = fid
                            receiverId = appState.currentUserId
                            amount = String(format: "%.2f", abs(balanceVal))
                        } else if balanceVal < -0.01 { // I owe them (Negative)
                            payerId = appState.currentUserId
                            receiverId = fid
                            amount = String(format: "%.2f", abs(balanceVal))
                        }
                    }
                }
            }
        } else if let group = group, let gid = group.id {
            // Default to first other member initially
            if let firstOther = group.members.first(where: { $0 != appState.currentUserId }) {
                receiverId = firstOther
            }
            
            // Check debt graph
            Task {
                let balances = await repo.calculateGroupBalances(groupId: gid, currentUserId: appState.currentUserId)
                let instructions = repo.calculateDebtResolution(balances: balances)
                
                await MainActor.run {
                    // 1. Do I owe anyone? (Priority)
                    if let debtToPay = instructions.first(where: { $0.debtorId == appState.currentUserId }) {
                        payerId = debtToPay.debtorId
                        receiverId = debtToPay.creditorId
                        amount = String(format: "%.2f", debtToPay.amount)
                    } 
                    // 2. Does anyone owe me?
                    else if let debtToReceive = instructions.first(where: { $0.creditorId == appState.currentUserId }) {
                        payerId = debtToReceive.debtorId
                        receiverId = debtToReceive.creditorId
                        amount = String(format: "%.2f", debtToReceive.amount)
                    }
                }
            }
        }
    }
    
    // MARK: - Step 1: Participants
    private var stepOneView: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Payer Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("PAYER (Who paid?)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    participantRow(id: payerId, label: "Payer")
                        .onTapGesture {
                            // Toggle between self and receiver if only 2 people, or show picker
                            // For simplicity, let's assume Payer is usually Self, but allow swap
                            if normalizeId(payerId) == normalizeId(appState.currentUserId) {
                                // Swap
                                payerId = receiverId
                                receiverId = appState.currentUserId
                            } else {
                                payerId = appState.currentUserId
                                // Reset receiver if needed, or keep
                                if receiverId == appState.currentUserId {
                                    // Receiver cannot be self if payer is self
                                    receiverId = "" 
                                }
                            }
                        }
                }
                
                Image(systemName: "arrow.down")
                    .font(.title2)
                    .foregroundColor(.secondary.opacity(0.5))
                
                // Receiver Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("RECEIVER (Who got paid?)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if let group = group {
                                ForEach(group.members.filter { $0 != payerId }, id: \.self) { memberId in
                                    participantOption(id: memberId, isSelected: receiverId == memberId)
                                        .onTapGesture {
                                            receiverId = memberId
                                            HapticManager.shared.light()
                                        }
                                }
                            } else if let friend = preSelectedFriend, let fid = friend.id {
                                participantOption(id: fid, isSelected: receiverId == fid)
                                    .onTapGesture { receiverId = fid }
                            } else {
                                // Show all friends?
                                ForEach(appState.friendRepo.friends) { friend in
                                    if let fid = friend.id, fid != payerId {
                                        participantOption(id: fid, isSelected: receiverId == fid)
                                            .onTapGesture { receiverId = fid }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
        }
    }
    
    private func participantRow(id: String, label: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 48, height: 48)
                Text(String(getName(for: id).prefix(1)).uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(getName(for: id))
                    .font(.body)
                    .fontWeight(.medium)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if label == "Payer" {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func participantOption(id: String, isSelected: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
                    .frame(width: 60, height: 60)
                
                Text(String(getName(for: id).prefix(1)).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .overlay(
                 Circle().stroke(Color.blue, lineWidth: isSelected ? 0 : 0) // Optional border
            )
            
            Text(getName(for: id))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .blue : .primary)
                .lineLimit(1)
        }
        .frame(width: 70)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring, value: isSelected)
    }
    
    // MARK: - Step 2: Amount
    private var stepTwoView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("Amount")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("0.00", text: $amount)
                .font(AppTypography.heroInput)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
                .focused($isAmountFocused)
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.margin)
    }
    
    // MARK: - Helpers
    private var stickyActionBar: some View {
        VStack {
            Button(action: {
                if currentStep == 1 {
                    HapticManager.shared.light()
                    withAnimation { currentStep = 2 }
                    // Auto focus after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAmountFocused = true
                    }
                } else {
                    submit()
                }
            }) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(currentStep == 1 ? "Next" : "Record Payment")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isValid)
        }
        .padding(.horizontal, AppSpacing.margin)
        .padding(.top, AppSpacing.compact)
        .padding(.bottom)
        .background(Color.backgroundPrimary)
        .ignoresSafeArea(.keyboard)
    }
    
    private var isValid: Bool {
        if currentStep == 1 {
            return !payerId.isEmpty && !receiverId.isEmpty && payerId != receiverId
        } else {
            return CurrencyInput.isValid(amount)
        }
    }
    
    private func getName(for id: String) -> String {
        if normalizeId(id) == normalizeId(appState.currentUserId) { return "You" }
        return appState.friendRepo.friends.first(where: { $0.id == id })?.name ?? "Member"
    }
    
    private func normalizeId(_ id: String) -> String {
        return id.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func submit() {
        guard let amountVal = CurrencyInput.parse(amount) else { return }
        isSubmitting = true
        
        Task {
            do {
                try await repo.settleUp(
                    payerId: payerId,
                    receiverId: receiverId,
                    groupId: group?.id,
                    amount: amountVal,
                    payerName: getName(for: payerId),
                    method: "Payment"
                )
                HapticManager.shared.success()
                isSubmitting = false
                dismiss()
            } catch {
                print("Failed to settle up: \(error)")
                HapticManager.shared.error()
                isSubmitting = false
            }
        }
    }
}
