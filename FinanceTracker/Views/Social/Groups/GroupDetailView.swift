import SwiftUI
import FirebaseFirestore

struct GroupDetailView: View {
    let group: FirestoreModels.Group
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var repo = SocialRepository()
    
    // UI State
    @State private var showingSettleUp = false
    @State private var showingSettings = false
    @State private var groupBalances: [String: Double] = [:]
    
    // Feature State
    @State private var pendingSplits: [FirestoreModels.SplitRequest] = []
    @State private var selectedSplit: FirestoreModels.SplitRequest?
    @State private var selectedTransaction: FirestoreModels.GroupTransaction?
    @State private var debtInstructions: [SocialRepository.DebtInstruction] = []
    
    // Undo State
    @State private var recentlyPaidSplit: FirestoreModels.SplitRequest?
    @State private var showUndoToast = false
    @State private var undoWorkItem: DispatchWorkItem?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: AppSpacing.section) {
                    // 1. Hero Section
                    VStack(spacing: AppSpacing.element) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.GradientTheme.gradient(for: group.color))
                                .frame(width: 86, height: 86)
                                .shadow(color: Color(hex: group.color).opacity(0.3), radius: 15, x: 0, y: 8)
                            
                            Image(systemName: group.icon)
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 4) {
                            Text(group.name)
                                .font(AppTypography.titleDisplay)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("\(group.members.count) members")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Action Buttons
                        HStack(spacing: AppSpacing.element) {
                            Button(action: { showingSettleUp = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "banknote.fill")
                                    Text("Settle Up")
                                }
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .clipShape(Capsule())
                                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.top, AppSpacing.section)
                    
                    // 1.5 Spending Summary
                    HStack(spacing: AppSpacing.element) {
                        let expenses = repo.groupTransactions.filter { $0.type != "settlement" }
                        
                        SpendingCard(
                            title: "Total Spend",
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
                    VStack(alignment: .leading, spacing: AppSpacing.element) {
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
                                                isOwed: bal > 0,
                                                isSelf: memberId == appState.currentUserId
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.margin)
                            }
                        }
                        
                        // 2.1 Debt Resolution (Collapsible or visible)
                        if !debtInstructions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested Repayments")
                                    .font(.headline)
                                    .padding(.horizontal, AppSpacing.margin)
                                    .padding(.top, 8)
                                
                                VStack(spacing: 12) {
                                    ForEach(debtInstructions) { instruction in
                                        DebtInstructionRow(
                                            debtorName: getMemberName(id: instruction.debtorId),
                                            creditorName: getMemberName(id: instruction.creditorId),
                                            amount: instruction.amount
                                        )
                                    }
                                }
                                .padding(.horizontal, AppSpacing.margin)
                            }
                        }
                    }
                    
                    // 2.5 Pending Splits (Interactive)
                    if !pendingSplits.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.element) {
                            Text("Your Pending Splits")
                                .font(.headline)
                                .padding(.horizontal, AppSpacing.margin)
                            
                            VStack(spacing: 12) {
                                ForEach(pendingSplits) { split in
                                    PendingSplitCard(split: split, userId: appState.currentUserId, onToggle: {
                                        handleSplitToggle(split)
                                    })
                                    .onTapGesture {
                                        selectedSplit = split
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.margin)
                        }
                    }
                    
                    // 3. Activity Feed
                    VStack(alignment: .leading, spacing: AppSpacing.element) {
                        Text("Activity")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        VStack(spacing: AppSpacing.compact) { // Tighter spacing for list feel
                            if repo.isLoading && repo.groupTransactions.isEmpty {
                                ProgressView()
                                    .padding()
                            } else if repo.groupTransactions.isEmpty {
                                Text("No transactions yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else {
                                ForEach(repo.groupTransactions) { transaction in
                                    GroupTransactionRow(transaction: transaction)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(AppRadius.medium)
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
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                    }
                }
                .padding(.bottom, 100)
            }
            
            // Undo Toast Overlay
            if showUndoToast {
                VStack {
                    Spacer()
                    UndoToast(text: "Marked as paid", onUndo: undoPayment)
                        .padding(.bottom, 20)
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
    
    // Logic Functions
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
        withAnimation { pendingSplits.removeAll { $0.id == split.id } }
        recentlyPaidSplit = split
        withAnimation { showUndoToast = true }
        undoWorkItem?.cancel()
        
        Task {
            do {
                try await SocialTransactionManager.shared.markSplitAsPaid(request: split, currentUserId: appState.currentUserId, currentUserName: appState.userName)
                loadGroupData()
            } catch {
                print("Error: \(error)")
                await MainActor.run { pendingSplits.append(split); pendingSplits.sort { $0.createdAt > $1.createdAt } }
            }
        }
        
        let workItem = DispatchWorkItem { withAnimation { showUndoToast = false; recentlyPaidSplit = nil } }
        undoWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }
    
    private func undoPayment() {
        guard let split = recentlyPaidSplit else { return }
        HapticManager.shared.light()
        withAnimation { showUndoToast = false }
        undoWorkItem?.cancel()
        withAnimation { pendingSplits.append(split); pendingSplits.sort { $0.createdAt > $1.createdAt } }
        
        Task {
            do {
                try await SocialTransactionManager.shared.unmarkSplitAsPaid(request: split, currentUserId: appState.currentUserId)
                loadGroupData()
            } catch { print("Error: \(error)") }
        }
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.GroupTransaction) {
        guard let groupId = group.id else { return }
        HapticManager.shared.light()
        Task {
            do {
                try await repo.deleteGroupTransaction(groupTx: transaction, groupId: groupId, currentUserId: appState.currentUserId)
                loadGroupData()
            } catch { print("Error: \(error)") }
        }
    }
    
    func getMemberName(id: String) -> String {
        if id == appState.currentUserId { return "You" }
        if let friend = appState.friendRepo.friends.first(where: { $0.id == id }) { return friend.name }
        if let guest = appState.guestRepo.guests.first(where: { $0.id == id }) { return guest.name }
        return "Member"
    }
}

// MARK: - Components (Specific to Group View)

struct DebtInstructionRow: View {
    let debtorName: String
    let creditorName: String
    let amount: Double
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ProfileAvatar(text: String(debtorName.prefix(1)), color: .red.opacity(0.7), size: 32)
                Text(debtorName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ProfileAvatar(text: String(creditorName.prefix(1)), color: .green.opacity(0.7), size: 32)
                Text(creditorName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("$\(String(format: "%.2f", amount))")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.small)
    }
}

struct PendingSplitCard: View {
    let split: FirestoreModels.SplitRequest
    let userId: String
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            let isOwed = split.fromUid == userId
            
            VStack(alignment: .leading, spacing: 4) {
                Text(split.note ?? "Split Expense")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    if isOwed {
                        Text("\(split.toName ?? "Friend") owes you")
                    } else {
                        Text("You owe \(split.fromName ?? "Friend")")
                    }
                    Text("• \(split.createdAt.formatted(date: .abbreviated, time: .omitted))")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", split.amount))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isOwed ? .functionalSuccess : .functionalError)
                
                Button(action: onToggle) {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
    }
}

struct GroupTransactionRow: View {
    let transaction: FirestoreModels.GroupTransaction
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.backgroundPrimary)
                    .frame(width: 40, height: 40)
                
                if transaction.type == "settlement" {
                     Image(systemName: "banknote.fill") // Fill for better viz
                        .font(.system(size: 18))
                        .foregroundColor(.functionalSuccess)
                } else {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(transaction.payerName) paid $\(String(format: "%.2f", transaction.amount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundColor(.tertiaryLabel)
        }
        .padding(12)
    }
}
