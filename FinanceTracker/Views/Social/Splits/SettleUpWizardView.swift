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
    
    @FocusState private var isAmountFocused: Bool
    @State private var direction: Edge = .trailing
    
    var body: some View {
        WizardLayout(
            title: stepTitle,
            currentStep: currentStep,
            totalSteps: 2,
            onBack: currentStep > 1 ? {
                direction = .leading
                withAnimation { currentStep = 1 }
                isAmountFocused = false
            } : nil,
            onClose: { dismiss() },
            direction: direction
        ) {
            if currentStep == 1 {
                stepOneView
            } else {
                stepTwoView
            }
        } actionBar: {
            Button(action: {
                if currentStep == 1 {
                    HapticManager.shared.light()
                    direction = .trailing
                    withAnimation { currentStep = 2 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        isAmountFocused = true
                    }
                } else {
                    submit()
                }
            }) {
                Text(currentStep == 1 ? "Next" : "Pay \(amount.isEmpty ? "0.00" : amount)")
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
            }
        } else if let group = group, let gid = group.id {
            if let firstOther = group.members.first(where: { $0 != appState.currentUserId }) {
                receiverId = firstOther
            }
            Task {
                let balances = await repo.calculateGroupBalances(groupId: gid, currentUserId: appState.currentUserId)
                let instructions = repo.calculateDebtResolution(balances: balances)
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
                                        .onTapGesture {
                                            payerId = memberId
                                            if receiverId == memberId { receiverId = "" }
                                            HapticManager.shared.light()
                                        }
                                }
                            } else {
                                // Friend Context: Just Me or Friend
                                participantCard(id: appState.currentUserId, isSelected: payerId == appState.currentUserId, isPayer: true)
                                    .onTapGesture { payerId = appState.currentUserId; if receiverId == payerId { receiverId = "" } }
                                
                                if let friend = preSelectedFriend, let fid = friend.id {
                                    participantCard(id: fid, isSelected: payerId == fid, isPayer: true)
                                        .onTapGesture { payerId = fid; if receiverId == payerId { receiverId = "" } }
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
                                        .onTapGesture {
                                            receiverId = memberId
                                            if payerId == memberId { payerId = "" }
                                            HapticManager.shared.light()
                                        }
                                }
                            } else {
                                // Friend Context
                                participantCard(id: appState.currentUserId, isSelected: receiverId == appState.currentUserId, isPayer: false)
                                    .onTapGesture { receiverId = appState.currentUserId; if payerId == receiverId { payerId = "" } }
                                
                                if let friend = preSelectedFriend, let fid = friend.id {
                                    participantCard(id: fid, isSelected: receiverId == fid, isPayer: false)
                                        .onTapGesture { receiverId = fid; if payerId == receiverId { payerId = "" } }
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
                    .fill(isSelected ? (isPayer ? Color.green : Color.blue) : Color(UIColor.secondarySystemBackground))
                    .frame(width: 64, height: 64)
                    .shadow(color: isSelected ? (isPayer ? Color.green.opacity(0.4) : Color.blue.opacity(0.4)) : Color.clear, radius: 8, y: 4)
                
                // Show Name instead of Initial inside circle if selected or always? 
                // Request says "include name underneath the icon", which is already there.
                // Request says "increase padding for icon".
                
                Text(String(getName(for: id).prefix(1)).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(8) // Increased padding for icon
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
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("Enter Amount")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$") // Currency Symbol
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
    
    // MARK: - Helpers
    // stickyActionBar removed (logic moved to body actionBar)
    
    private var isValid: Bool {
        if currentStep == 1 {
            return !payerId.isEmpty && !receiverId.isEmpty && payerId != receiverId
        } else {
            return (Double(amount) ?? 0) > 0
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
    
    private func submit() {
        guard let amountVal = Double(amount) else { return }
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
