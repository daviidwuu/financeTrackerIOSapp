import SwiftUI
import FirebaseFirestore

struct FriendDetailView: View {
    let friend: FirestoreModels.Friend
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var repo = SocialRepository()
    
    // UI State
    @State private var showingSettleUp = false
    @State private var selectedTransaction: FirestoreModels.TransactionModel?
    
    // Undo State
    @State private var recentlyToggledTx: FirestoreModels.TransactionModel?
    @State private var showUndoToast = false
    @State private var undoWorkItem: DispatchWorkItem?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: AppSpacing.section) {
                    // 1. Header
                    DetailHeaderView(
                        title: friend.name,
                        subtitle: "@\(friend.username)",
                        onBack: { dismiss() },
                        onMenu: nil,
                        backgroundColor: Color.backgroundPrimary,
                        textColor: .primary
                    ) {
                        ProfileAvatar(
                            text: String(friend.name.prefix(1)),
                            color: Color.random(seed: friend.name),
                            size: AppSize.avatarHero
                        )
                    } actions: {
                        HStack(spacing: 16) {
                            Button(action: { showingSettleUp = true }) {
                                HStack {
                                    Text("Settle")
                                        .foregroundColor(colorScheme == .dark ? .black : .white)
                                }
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(colorScheme == .dark ? Color.white : Color.black)
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                            }
                            
                            let balance = repo.friendBalances.values.reduce(0, +)
                            if balance > 0.01 {
                                Button(action: sendNudge) {
                                    Image(systemName: "hand.wave.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primary)
                                        .padding(14)
                                        .background(Color.primary.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                    
                    // 2. Overview & Net Balance
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overview")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        let balance = repo.friendBalances.values.reduce(0, +)
                        
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(balance >= 0 ? "Owed to You" : "You Owe")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(String(format: "$%.2f", abs(balance)))
                                    .font(AppTypography.titleDisplay)
                                    .foregroundColor(balance >= 0 ? .green : .red)
                                
                                if balance == 0 {
                                    Text("All settled up")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Spacer()
                            
                            // Mini Chart or Icon
                            ZStack {
                                Circle()
                                    .fill(Color.primary.opacity(0.05))
                                    .frame(width: 56, height: 56)
                                Image(systemName: balance >= 0 ? "arrow.down.left" : "arrow.up.right")
                                    .font(.title2)
                                    .foregroundColor(balance >= 0 ? .green : .red)
                            }
                        }
                        .padding(20)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(AppRadius.medium)
                        .padding(.horizontal, AppSpacing.margin)
                    }
                    
                    // 3. Transactions List
                    VStack(alignment: .leading, spacing: AppSpacing.element) {
                        Text("History")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        VStack(spacing: 16) {
                            if repo.isLoading && repo.friendTransactions.isEmpty {
                                ProgressView().padding()
                            } else if repo.friendTransactions.isEmpty {
                                ContentUnavailableView("No history", systemImage: "clock.arrow.circlepath", description: Text("Shared expenses will appear here."))
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(repo.friendTransactions) { transaction in
                                        FriendCardRow(transaction: transaction, friendName: friend.name)
                                            .background(Color(UIColor.secondarySystemBackground))
                                            .cornerRadius(AppRadius.medium)
                                            .onTapGesture { selectedTransaction = transaction }
                                            .contextMenu {
                                                Button { toggleTransactionStatus(transaction) } label: {
                                                    let isPaid = (transaction.note ?? "").lowercased() == "paid"
                                                    Label(isPaid ? "Mark as Pending" : "Mark as Paid", systemImage: isPaid ? "arrow.uturn.backward" : "checkmark.circle")
                                                }
                                                
                                                 Button(role: .destructive) { deleteTransaction(transaction) } label: {
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
            
            // Undo Toast
            if showUndoToast {
                UndoToast(text: "Status updated", onUndo: undoToggle)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear { loadData() }
        .sheet(isPresented: $showingSettleUp) {
            SettleUpWizardView(group: nil, preSelectedFriend: friend)
                .presentationDetents([.large])
                .onDisappear { loadData() }
        }
        .sheet(item: $selectedTransaction, onDismiss: { loadData() }) { tx in
             // Always show SplitRequestDetailView if we can reconstruct the request
             if let req = reconstructRequest(from: tx) {
                SplitRequestDetailView(request: req)
                    .presentationDetents([.medium, .large])
            } else {
                Text("Error loading details")
            }
        }
    }
    
    // Logic
    private func loadData() {
        if let fid = friend.id {
            repo.fetchFriendTransactions(currentUserId: appState.currentUserId, friendId: fid)
        }
    }
    
    private func sendNudge() {
        guard let fid = friend.id else { return }
        HapticManager.shared.medium()
        Task {
            do {
                try await repo.sendNudge(friendId: fid)
            } catch { print("Error sending nudge: \(error)") }
        }
    }
    
    private func reconstructRequest(from tx: FirestoreModels.TransactionModel) -> FirestoreModels.SplitRequest? {
        guard let id = tx.id else { return nil }
        let status = FirestoreModels.SplitRequest.RequestStatus(rawValue: tx.note ?? "") ?? .pending
        let isIncome = tx.type == "income"
        
        let fromUid = isIncome ? (friend.id ?? "") : appState.currentUserId
        let fromName = isIncome ? friend.name : "You"
        let toUid = isIncome ? appState.currentUserId : (friend.id ?? "")
        let toName = isIncome ? "You" : friend.name
        
        // Use the 'source' field if available, which holds the original transaction ID
        let originalTxId = tx.source ?? id
        
        return FirestoreModels.SplitRequest(
            id: id,
            transactionId: originalTxId,
            groupId: nil,
            fromUid: fromUid,
            toUid: toUid,
            fromName: fromName,
            toName: toName,
            amount: abs(tx.amount),
            currency: nil,
            note: tx.title,
            status: status,
            dependencyId: nil,
            lastNudgedAt: nil,
            createdAt: tx.date
        )
    }
    
    private func undoToggle() {
        guard let tx = recentlyToggledTx, let req = reconstructRequest(from: tx) else { return }
        let targetStatus = (tx.note ?? "").lowercased()
        
        HapticManager.shared.medium()
        
        Task {
            do {
                if targetStatus == "paid" {
                    try await SocialTransactionManager.shared.markSplitAsPaid(request: req, currentUserId: appState.currentUserId, currentUserName: appState.userName)
                } else {
                    try await SocialTransactionManager.shared.unmarkSplitAsPaid(request: req, currentUserId: appState.currentUserId)
                }
                
                await MainActor.run {
                    showUndoToast = false // Hide toast immediately on undo
                    loadData()
                }
            } catch {
                print("Error undoing toggle: \(error)")
            }
        }
    }
    
    private func toggleTransactionStatus(_ transaction: FirestoreModels.TransactionModel) {
        guard let req = reconstructRequest(from: transaction) else { return }
        let isPaid = (transaction.note ?? "").lowercased() == "paid"
        
        HapticManager.shared.medium()
        recentlyToggledTx = transaction
        
        Task {
            do {
                if !isPaid {
                    try await SocialTransactionManager.shared.markSplitAsPaid(request: req, currentUserId: appState.currentUserId, currentUserName: appState.userName)
                } else {
                    try await SocialTransactionManager.shared.unmarkSplitAsPaid(request: req, currentUserId: appState.currentUserId)
                }
                
                await MainActor.run {
                    showUndoToast = true
                    loadData()
                    
                    undoWorkItem?.cancel()
                    let workItem = DispatchWorkItem { withAnimation { showUndoToast = false } }
                    undoWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
                }
            } catch {
                print("Error toggling: \(error)")
            }
        }
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.TransactionModel) {
         guard let id = transaction.id else { return }
        HapticManager.shared.light()
        withAnimation { repo.removeLocalTransaction(id: id) }
        Task {
            do {
                try await repo.deleteFriendTransaction(transactionId: id)
            } catch { await MainActor.run { loadData() } }
        }
    }
}

// MARK: - Subviews

struct FriendCardRow: View {
    let transaction: FirestoreModels.TransactionModel
    let friendName: String
    
    @State private var fetchedOriginalAmount: Double?
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            CategoryIconView(
                category: transaction.subtitle,
                iconOverride: transaction.icon,
                colorOverride: transaction.colorHex,
                type: transaction.type
            )
            
            VStack(alignment: .leading, spacing: 4) {
                // Title is the core data
                Text(transaction.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Logic:
                // 1. If I paid (Income), 'amount' is what Friend owes me ($51). 
                //    I want to show "You paid $100" (Total) or if not available, at least "You lent $51".
                // 2. If Friend paid (Expense), 'amount' is what I owe Friend ($51).
                //    I want to show "Friend paid $100" (Total) or "Friend lent you $51".
                
                let totalAmount = transaction.originalAmount ?? fetchedOriginalAmount
                let isYouPaid = transaction.type == "income"
                
                if let total = totalAmount {
                    // We have the full original bill amount
                    let formattedTotal = String(format: "$%.2f", total)
                    Text(isYouPaid ? "You paid \(formattedTotal)" : "\(friendName) paid \(formattedTotal)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Fallback: We only have the split share amount
                    let shareAmount = abs(transaction.amount)
                    let formattedShare = String(format: "$%.2f", shareAmount)
                    Text(isYouPaid ? "You lent \(formattedShare)" : "\(friendName) lent you \(formattedShare)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Status Badge
                if let status = transaction.note, !status.isEmpty, ["pending", "paid", "accepted", "declined"].contains(status) {
                    Text(status.capitalized)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor(status).opacity(0.1))
                        .foregroundColor(statusColor(status))
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", abs(transaction.amount)))")
                    .font(.headline)
                    .fontWeight(.bold)
                    // Green for Credit (You Paid), Red for Debt (Friend Paid)
                    .foregroundColor(transaction.type == "income" ? .green : .red)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .padding(AppSpacing.element)
        .task {
            // Fetch original amount if missing
            if transaction.originalAmount == nil, let sourceId = transaction.source {
                do {
                    let doc = try await Firestore.firestore().collection("transactions").document(sourceId).getDocument()
                    if let tx = try? doc.data(as: FirestoreModels.TransactionModel.self) {
                        await MainActor.run {
                            self.fetchedOriginalAmount = abs(tx.amount)
                        }
                    }
                } catch {
                    print("Error fetching original transaction: \(error)")
                }
            }
        }
    }
    
    func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "pending": return .orange
        case "paid", "settled", "accepted": return .green
        case "declined": return .red
        default: return .secondary
        }
    }
}
