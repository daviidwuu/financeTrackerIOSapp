import SwiftUI

struct GroupDetailView: View {
    let group: FirestoreModels.Group
    @EnvironmentObject var appState: AppState
    @StateObject private var repo = SocialRepository()
    @State private var showingSettleUp = false
    @State private var showingSettings = false
    @State private var groupBalances: [String: Double] = [:]
    
    var body: some View {
        ZStack(alignment: .bottom) { // Changed to ZStack for floating content
            Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Hero Section
                    VStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: group.color))
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(hex: group.color).opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: group.icon)
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 4) {
                            Text(group.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("\(group.members.count) members")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Action Buttons
                        HStack(spacing: 16) {
                            Button(action: {
                                showingSettleUp = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "banknote.fill")
                                    Text("Settle Up")
                                }
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            
                            Button(action: {
                                showingSettings = true
                            }) {
                                Image(systemName: "gearshape.fill")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(width: 50) // Force circle-like aspect if needed or just use standard secondary
                        }
                    }
                    .padding(.top, 20)
                    

                    
                    // 1.5 Spending Summary
                    HStack(spacing: 12) {
                        let expenses = repo.groupTransactions.filter { $0.type != "settlement" }
                        
                        SpendingCard(
                            title: "Total Group Spend",
                            amount: expenses.reduce(0) { $0 + $1.amount },
                            icon: "chart.bar.fill",
                            color: .blue
                        )
                        
                        SpendingCard(
                            title: "You Paid",
                            amount: expenses.filter { $0.payerId == appState.currentUserId }.reduce(0) { $0 + $1.amount },
                            icon: "person.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    
                    // 2. Balances
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Balances")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        if groupBalances.isEmpty {
                            Text("No active debts")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, AppSpacing.margin)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(group.members, id: \.self) { memberId in
                                        if let bal = groupBalances[memberId], abs(bal) > 0.01 {
                                            BalanceCard(
                                                name: getMemberName(id: memberId),
                                                amount: abs(bal),
                                                isOwed: bal > 0, // Positive means they paid (are owed), Negative means they consumed (owe)
                                                // Actually logic in repo:
                                                // balances[req.fromUid] += amount (They PAID -> They are OWED positive)
                                                // balances[req.toUid] -= amount (They CONSUMED -> They OWE negative)
                                                // So > 0 means "Gets", < 0 means "Owes"
                                                isSelf: memberId == appState.currentUserId
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.margin)
                            }
                        }
                        
                        // 2.1 Debt Settings (Who owes Who)
                        if !debtInstructions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested Repayments")
                                    .font(.headline)
                                    .padding(.horizontal, AppSpacing.margin)
                                
                                VStack(spacing: 12) {
                                    ForEach(debtInstructions) { instruction in
                                        HStack(spacing: 12) {
                                            // Debtor
                                            HStack(spacing: 8) {
                                                ProfileAvatar(text: String(getMemberName(id: instruction.debtorId).prefix(1)), color: .red, size: 32)
                                                Text(getMemberName(id: instruction.debtorId))
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .lineLimit(1)
                                            }
                                            
                                            // Arrow
                                            Image(systemName: "arrow.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            // Creditor
                                            HStack(spacing: 8) {
                                                ProfileAvatar(text: String(getMemberName(id: instruction.creditorId).prefix(1)), color: .green, size: 32)
                                                Text(getMemberName(id: instruction.creditorId))
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            // Amount
                                            Text("$\(String(format: "%.2f", instruction.amount))")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                        }
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .padding(.horizontal, AppSpacing.margin)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 2.5 Pending Splits (Interactive)
                    if !pendingSplits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Pending Splits")
                                .font(.headline)
                                .padding(.horizontal, AppSpacing.margin)
                            
                            VStack(spacing: 0) {
                                ForEach(pendingSplits) { split in
                                    HStack(spacing: 12) {
                                        // Dynamic Icon/Text
                                        // If fromUid == current: "Someone owes You" (Green)
                                        // If toUid == current: "You owe Someone" (Red)
                                        let isOwed = split.fromUid == appState.currentUserId
                                        let otherPartyName = isOwed ? "Friend" : (split.fromName ?? "Friend")
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(split.note ?? "Split Expense")
                                                .font(.body)
                                                .fontWeight(.medium)
                                            
                                            HStack(spacing: 4) {
                                                if isOwed {
                                                    Text("owes you")
                                                    Text("$\(String(format: "%.2f", split.amount))")
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.green)
                                                } else {
                                                    Text("you owe")
                                                    Text("$\(String(format: "%.2f", split.amount))")
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.red)
                                                }
                                                Text("• \(split.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                                    .foregroundColor(.secondary)
                                            }
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Checkbox (Mark as Paid)
                                        Button(action: {
                                            handleSplitToggle(split)
                                        }) {
                                            Image(systemName: "circle")
                                                .font(.title2)
                                                .foregroundColor(.secondary.opacity(0.3))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedSplit = split
                                    }
                                    .padding(.horizontal, AppSpacing.margin)
                                    .padding(.bottom, 8)
                                }
                            }
                        }
                    }

                    // 3. Activity Feed (Existing)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(repo.groupTransactions) { transaction in
                                GroupTransactionRow(transaction: transaction)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedTransaction = transaction
                                    }
                                    .contextMenu {
                                        if transaction.payerId == appState.currentUserId {
                                            Button(role: .destructive) {
                                                deleteTransaction(transaction)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                            }
                            
                            if repo.isLoading {
                                ProgressView()
                                    .padding()
                            } else if repo.groupTransactions.isEmpty {
                                Text("No transactions yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                    }
                }
                .padding(.bottom, 100) // Space for bottom
            }
            
            // Undo Toast Overlay
            if showUndoToast {
                VStack {
                    Spacer()
                    UndoToast(text: "Marked as paid", onUndo: undoPayment)
                        .padding(.bottom, 110) // Above TabBar/Buttons
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadGroupData()
        }
        .sheet(isPresented: $showingSettings) {
             GroupCreationWizardView(groupToEdit: group)
        }
        .sheet(isPresented: $showingSettleUp) {
            SettleUpWizardView(group: group, preSelectedFriend: nil)
                .presentationDetents([.large])
        }
        .sheet(item: $selectedSplit) { split in
            SplitRequestDetailView(request: split)
        }
        .sheet(item: $selectedTransaction) { transaction in
            GroupTransactionDetailView(transaction: transaction)
        }
    }
    
    // State for pending splits
    @State private var pendingSplits: [FirestoreModels.SplitRequest] = []
    @State private var selectedSplit: FirestoreModels.SplitRequest?
    @State private var selectedTransaction: FirestoreModels.GroupTransaction?
    @State private var debtInstructions: [SocialRepository.DebtInstruction] = []
    
    // Undo State
    @State private var recentlyPaidSplit: FirestoreModels.SplitRequest?
    @State private var showUndoToast = false
    @State private var undoWorkItem: DispatchWorkItem?
    
    // ... loadGroupData ...
    
    private func loadGroupData() {
        if let groupId = group.id {
            repo.fetchGroupTransactions(groupId: groupId)
            Task {
                groupBalances = await repo.calculateGroupBalances(groupId: groupId, currentUserId: appState.currentUserId)
                debtInstructions = repo.calculateDebtResolution(balances: groupBalances)
                pendingSplits = await repo.fetchMyGroupSplits(groupId: groupId, currentUserId: appState.currentUserId)
            }
        }
    }
    
    private func handleSplitToggle(_ split: FirestoreModels.SplitRequest) {
        HapticManager.shared.success()
        
        // 1. Optimistic Remove
        withAnimation {
            pendingSplits.removeAll { $0.id == split.id }
        }
        
        // 2. Set Undo State
        recentlyPaidSplit = split
        withAnimation { showUndoToast = true }
        
        // Cancel previous timer
        undoWorkItem?.cancel()
        
        // 3. Schedule "Finalize" (actually we already marked it, but we can't easily "hold" the write without risking data loss if app closes.
        // Better approach for Robustness: Execute Write Immediately (Batch). If Undo, Execute Revert Write.
        // This is safer than "waiting to write" because if the app crashes, the user *thinks* they paid but didn't.
        // So we Write NOW. Undo handles the Revert.
        
        Task {
            do {
                try await repo.markSplitAsPaid(request: split, currentUserId: appState.currentUserId, currentUserName: appState.userName)
                loadGroupData() // Refresh feed
            } catch {
                print("Error marking split as paid: \(error)")
                // Revert UI if error
                await MainActor.run {
                    pendingSplits.append(split)
                    pendingSplits.sort { $0.createdAt > $1.createdAt }
                }
            }
        }
        
        // Auto-dismiss toast
        let workItem = DispatchWorkItem {
            withAnimation {
                showUndoToast = false
                recentlyPaidSplit = nil
            }
        }
        undoWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }
    
    private func undoPayment() {
        guard let split = recentlyPaidSplit else { return }
        HapticManager.shared.light()
        
        // 1. Hide Toast
        withAnimation { showUndoToast = false }
        undoWorkItem?.cancel()
        
        // 2. Optimistic Add Back
        withAnimation {
            pendingSplits.append(split)
            pendingSplits.sort { $0.createdAt > $1.createdAt }
        }
        
        // 3. Revert in Firestore
        Task {
            do {
                try await repo.unmarkSplitAsPaid(request: split)
                loadGroupData() // Refresh to remove feed item (if we implemented deletion) or just update status
            } catch {
                print("Error undoing payment: \(error)")
            }
        }
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.GroupTransaction) {
        guard let groupId = group.id else { return }
        HapticManager.shared.light()
        
        Task {
            do {
                try await repo.deleteGroupTransaction(groupTx: transaction, groupId: groupId, currentUserId: appState.currentUserId)
                loadGroupData() // Refresh
            } catch {
                print("Error deleting transaction: \(error)")
            }
        }
    }
    
    func getMemberName(id: String) -> String {
        // ... existing ...
        if id == appState.currentUserId { return "You" }
        
        // Check Friends
        if let friend = appState.friendRepo.friends.first(where: { $0.id == id }) {
            return friend.name
        }
        
        // Check Guests
        if let guest = appState.guestRepo.guests.first(where: { $0.id == id }) {
            return guest.name
        }
        
        return "Member"
    }
}

// Helper for Toast
struct UndoToast: View {
    let text: String
    let onUndo: () -> Void
    
    var body: some View {
        HStack {
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: onUndo) {
                Text("Undo")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#FFCC00")) // Yellow for visibility
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(AppRadius.medium)
        .padding(.horizontal, 24)
        .shadow(radius: 10)
    }
}

struct BalanceCard: View {
    let name: String
    let amount: Double
    let isOwed: Bool 
    let isSelf: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProfileAvatar(text: String(name.prefix(1)), color: .blue, size: 32)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(isOwed ? "gets $\(String(format: "%.2f", amount))" : "owes $\(String(format: "%.2f", amount))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isOwed ? Color(hex: "#34C759") : Color(hex: "#FF3B30"))
            }
        }
        .padding(12)
        .frame(width: 120)
        .background(isSelf ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(isSelf ? Color.secondary.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

struct GroupTransactionRow: View {
    let transaction: FirestoreModels.GroupTransaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(width: 40, height: 40)
                
                // If it's settlement
                if transaction.type == "settlement" {
                     Image(systemName: "banknote")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                } else {
                    // Category icon or generic
                    Image(systemName: "cart.fill") // Placeholder, real impl needs category
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("\(transaction.payerName) paid $\(String(format: "%.2f", transaction.amount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .padding(.horizontal, AppSpacing.margin)
    }
}


