import SwiftUI

struct FriendDetailView: View {
    let friend: FirestoreModels.Friend
    @EnvironmentObject var appState: AppState
    @StateObject private var repo = SocialRepository()
    @State private var balances: [String: Double] = [:] // Changed to Dictionary
    @State private var showingSettleUp = false
    
    // Details Sheet
    @State private var selectedTransaction: FirestoreModels.Transaction?
    
    // Undo State
    @State private var recentlyToggledTx: FirestoreModels.Transaction?
    @State private var showUndoToast = false
    @State private var undoWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack(alignment: .bottom) { // Changed to ZStack for Toast
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        ProfileAvatar(
                            text: String(friend.name.prefix(1)),
                            color: Color.random(seed: friend.name),
                            size: 80
                        )
                        
                        Text(friend.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(friend.username)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Actions (Settle Up & Nudge)
                        HStack(spacing: 12) {
                            if !balances.isEmpty {
                                Button(action: { showingSettleUp = true }) {
                                    Text("Settle Up")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(Color.primary)
                                        .foregroundColor(Color.backgroundPrimary)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            // Show Nudge if they owe you anything
                            if balances.values.contains(where: { $0 > 0.01 }) {
                                Button(action: sendNudge) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "hand.wave.fill")
                                        Text("Nudge")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.top, 40)
                    
                    // Stats (Multi-Currency)
                    VStack(spacing: 12) {
                        if balances.isEmpty {
                            Text("All settled up!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                        } else {
                            // Sort balances: Positive (Owes You) first, then Negative
                            ForEach(balances.sorted(by: { $0.value > $1.value }), id: \.key) { currency, amount in
                                HStack {
                                    Text(amount > 0 ? "Owes You" : "You Owe")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(currency) \(String(format: "%.2f", abs(amount)))")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(amount > 0 ? .green : .red)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // History
                    VStack(alignment: .leading, spacing: 16) {
                        Text("History")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if repo.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if repo.friendTransactions.isEmpty {
                            Text("No shared history yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(repo.friendTransactions) { transaction in
                                    FriendTransactionRow(transaction: transaction) { tx in
                                        handleToggle(tx)
                                    }
                                    .contentShape(Rectangle()) // Make entire row tappable
                                    .onTapGesture {
                                        // Open Details
                                        HapticManager.shared.light()
                                        selectedTransaction = transaction
                                    }
                                    .contextMenu {
                                        // Only allow deleting if we created the request (indicated by "income" type in this view's Logic)
                                        if transaction.type == "income" {
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
                    }
                }
                .padding(.bottom, 100) // Increased padding for toast space
            }
            .refreshable {
                loadData()
            }
            
            // Undo Toast
            if showUndoToast {
                UndoToast(text: "Status updated", onUndo: undoToggle)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .navigationTitle(friend.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showingSettleUp) {
            SettleUpWizardView(group: nil, preSelectedFriend: friend)
                .presentationDetents([.large])
                .onDisappear {
                    loadData() // Refresh on dismiss
                }
        }
        // Transaction Details Sheet
        .sheet(item: $selectedTransaction) { tx in
            // We need to fetch the underlying SplitRequest usually, but for now 
            // since we don't have the full object, we can reconstruct or fetch.
            // The `transaction` here is a `FirestoreModels.Transaction` constructed from a `SplitRequest`.
            // Let's create a temporary SplitRequest object to view, or fetch the real one.
            // Simplified: Reconstruct from Tx data since we mapped it 1:1 in Repo.
            if let req = reconstructRequest(from: tx) {
                NavigationView {
                    SplitRequestDetailView(request: req)
                }
                .presentationDetents([.fraction(0.6)])
            } else {
                Text("Error loading details")
            }
        }
    }
    
    // Helper to reconstruct SplitRequest from the unified Transaction model for viewing
    private func reconstructRequest(from tx: FirestoreModels.Transaction) -> FirestoreModels.SplitRequest? {
        guard let id = tx.id else { return nil }
        
        // Map status back from note
        let status = FirestoreModels.SplitRequest.RequestStatus(rawValue: tx.note ?? "") ?? .pending
        
        return FirestoreModels.SplitRequest(
            id: id,
            transactionId: id,
            groupId: nil,
            fromUid: tx.type == "income" ? appState.currentUserId : (friend.id ?? ""),
            toUid: tx.type == "income" ? (friend.id ?? "") : appState.currentUserId,
            fromName: tx.type == "income" ? "You" : friend.name,
            amount: tx.amount,
            currency: nil, // We lost this in the map, but it's okay for display purposes (shows symbol)
            note: tx.title,
            status: status,
            dependencyId: nil,
            lastNudgedAt: nil,
            createdAt: tx.date
        )
    }
    
    private func loadData() {
        if let fid = friend.id {
            repo.fetchFriendTransactions(currentUserId: appState.currentUserId, friendId: fid)
            Task {
                balances = await repo.calculateFriendBalance(currentUserId: appState.currentUserId, friendId: fid)
            }
        }
    }
    
    private func sendNudge() {
        guard let fid = friend.id else { return }
        HapticManager.shared.medium()
        
        Task {
            do {
                try await repo.sendNudge(to: fid, currentUserId: appState.currentUserId)
                // We could show a specific toast: "Nudge sent!"
                // For now, Haptic + maybe generic feedback
            } catch {
                print("Error sending nudge: \(error)")
            }
        }
    }
    
    private func handleToggle(_ transaction: FirestoreModels.Transaction) {
        guard let requestId = transaction.id else { return }
        
        HapticManager.shared.light()
        
        let currentStatus = transaction.note
        let isPaid = currentStatus == FirestoreModels.SplitRequest.RequestStatus.paid.rawValue
        let newStatus: FirestoreModels.SplitRequest.RequestStatus = isPaid ? .accepted : .paid
        
        // Undo State
        recentlyToggledTx = transaction
        withAnimation { showUndoToast = true }
        undoWorkItem?.cancel()
        
        Task {
            do {
                try await RequestRepository().updateRequestStatus(userId: appState.currentUserId, requestId: requestId, status: newStatus)
                await MainActor.run { loadData() }
            } catch {
                print("Error toggling payment: \(error)")
            }
        }
        
        // Auto-dismiss
        let workItem = DispatchWorkItem {
            withAnimation {
                showUndoToast = false
                recentlyToggledTx = nil
            }
        }
        undoWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }
    
    private func undoToggle() {
        guard let tx = recentlyToggledTx, let requestId = tx.id else { return }
        HapticManager.shared.light()
        
        withAnimation { showUndoToast = false }
        undoWorkItem?.cancel()
        
        // Revert Logic
        var revertStatus: FirestoreModels.SplitRequest.RequestStatus = .accepted
        if tx.note == FirestoreModels.SplitRequest.RequestStatus.paid.rawValue {
            revertStatus = .paid
        } else if tx.note == FirestoreModels.SplitRequest.RequestStatus.accepted.rawValue {
            revertStatus = .accepted
        } else if tx.note == FirestoreModels.SplitRequest.RequestStatus.pending.rawValue {
            revertStatus = .pending
        }
        
        Task {
            do {
                try await RequestRepository().updateRequestStatus(userId: appState.currentUserId, requestId: requestId, status: revertStatus)
                await MainActor.run { loadData() }
            } catch {
                print("Error undoing toggle: \(error)")
            }
        }
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.Transaction) {
        HapticManager.shared.light()
        Task {
            do {
                try await repo.deleteFriendTransaction(transaction: transaction, currentUserId: appState.currentUserId)
                await MainActor.run { loadData() }
            } catch {
                print("Error deleting friend transaction: \(error)")
            }
        }
    }
}

struct FriendTransactionRow: View {
    let transaction: FirestoreModels.Transaction
    var onTogglePaid: ((FirestoreModels.Transaction) -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: transaction.colorHex).opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: transaction.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: transaction.colorHex))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(transaction.subtitle ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text((transaction.type == "income" ? "+" : "") + String(format: "$%.2f", abs(transaction.amount)))
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundColor(transaction.type == "income" ? .green : .primary)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Interactive Payment Checkbox (Only if onTogglePaid is provided)
            if let onToggle = onTogglePaid {
                Button(action: {
                    onToggle(transaction)
                }) {
                    let isPaid = transaction.note == FirestoreModels.SplitRequest.RequestStatus.paid.rawValue
                    Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isPaid ? .green : .secondary.opacity(0.3))
                }
                .buttonStyle(.plain) // Prevents row tap conflict
                .padding(.leading, 8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8) // Touch target
        .background(Color(UIColor.systemBackground)) // Tap area
    }
}
