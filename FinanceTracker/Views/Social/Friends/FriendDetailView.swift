import SwiftUI
import FirebaseFirestore

struct FriendDetailView: View {
    let friend: FirestoreModels.Friend
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
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
                    // 1. New Custom Header
                    FriendHeaderView(
                        friend: friend,
                        balance: repo.friendBalances.values.reduce(0, +),
                        onSettleUp: { showingSettleUp = true },
                        onNudge: sendNudge
                    )
                    
                    // 1.5 Spending Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Summary")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        if !repo.friendBalances.isEmpty {
                            // Multi-currency support
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(repo.friendBalances.sorted(by: { $0.value > $1.value }), id: \.key) { currency, amount in
                                        SpendingCard(
                                            title: amount > 0 ? "Owed to You" : "You Owe",
                                            amount: abs(amount),
                                            icon: amount > 0 ? "arrow.down.left" : "arrow.up.right",
                                            color: amount > 0 ? .green : .red
                                        )
                                    }
                                }
                                .padding(.horizontal, AppSpacing.margin)
                            }
                        } else {
                            // All Settled
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("All settled up!")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(AppRadius.medium)
                            .padding(.horizontal, AppSpacing.margin)
                        }
                    }
                    
                    // 2. Transactions List
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
                                LazyVStack(spacing: 16) { // ✅ LazyVStack
                                    ForEach(repo.friendTransactions) { transaction in
                                        FriendCardRow(transaction: transaction, friendName: friend.name)
                                            .background(Color(UIColor.secondarySystemBackground)) // Card BG
                                            .cornerRadius(AppRadius.medium)
                                            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
                                            .onTapGesture { selectedTransaction = transaction }
                                            .contextMenu {
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
        .overlay(
            // ✅ Sticky Back Button
            GeometryReader { geo in
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, geo.safeAreaInsets.top + 8)
            }
            .ignoresSafeArea(edges: .top),
            alignment: .top
        )
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .top)
        .onAppear { loadData() }
        .sheet(isPresented: $showingSettleUp) {
            SettleUpWizardView(group: nil, preSelectedFriend: friend)
                .presentationDetents([.large])
                .onDisappear { loadData() }
        }
        .sheet(item: $selectedTransaction, onDismiss: { loadData() }) { tx in
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
                try await repo.sendNudge(to: fid, currentUserId: appState.currentUserId)
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
        
        return FirestoreModels.SplitRequest(
            id: id,
            transactionId: id,
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
    
    private func undoToggle() {}
    
    private func deleteTransaction(_ transaction: FirestoreModels.TransactionModel) {
         guard let id = transaction.id else { return }
        HapticManager.shared.light()
        withAnimation { repo.removeLocalTransaction(id: id) }
        Task {
            do {
                try await repo.deleteFriendTransaction(transaction: transaction, currentUserId: appState.currentUserId)
            } catch { await MainActor.run { loadData() } }
        }
    }
}

// MARK: - Subviews

struct FriendHeaderView: View {
    let friend: FirestoreModels.Friend
    let balance: Double
    let onSettleUp: () -> Void
    let onNudge: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background with Black
            Color.black
                .frame(height: 280)
                .overlay(Color.black.opacity(0.2))
            
            VStack(spacing: 0) {
                // Nav Bar Removed (Floating)
                
                Spacer()
                
                // Profile Info
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                        
                        Text(String(friend.name.prefix(1)).uppercased())
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5) // ✅ Enhanced Shadow
                    }
                    
                    VStack(spacing: 4) {
                        Text(friend.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                        
                        Text(friend.username)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    // Actions
                    HStack(spacing: 16) {
                        Button(action: onSettleUp) {
                            HStack {
                                Image(systemName: "banknote.fill")
                                Text("Settle Up")
                            }
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Color.random(seed: friend.id ?? friend.name))
                            .frame(maxWidth: .infinity) // ✅ Full Width
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, balance > 0.01 ? 0 : 48) // Adjust if button is alone
                        
                        if balance > 0.01 {
                            Button(action: onNudge) {
                                Image(systemName: "hand.wave.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(14)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                    }

                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .frame(height: 280)
        .mask(Rectangle())
    }
}

struct FriendCardRow: View {
    let transaction: FirestoreModels.TransactionModel
    let friendName: String
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            ZStack {
                Circle()
                    .fill(Color(hex: transaction.colorHex ?? "#000000").opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: transaction.icon ?? "dollarsign.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: transaction.colorHex ?? "#000000"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Title is the core data
                Text(transaction.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                let isYouPaid = transaction.type == "income"
                // Simplify: Just "You paid" or "David paid"
                let payerText = isYouPaid ? "You paid" : "\(friendName) paid"
                
                Text(payerText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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

