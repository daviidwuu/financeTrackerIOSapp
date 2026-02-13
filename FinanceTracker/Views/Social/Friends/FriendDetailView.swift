import SwiftUI
import FirebaseFirestore

struct FriendDetailView: View {
    let friend: FirestoreModels.Friend
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var repo = SocialRepository()
    
    // UI State
    @State private var showingSettleUp = false
    @State private var selectedTransaction: FirestoreModels.Transaction?
    
    // Undo State
    @State private var recentlyToggledTx: FirestoreModels.Transaction?
    @State private var showUndoToast = false
    @State private var undoWorkItem: DispatchWorkItem?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: AppSpacing.element) {
                        ProfileAvatar(text: String(friend.name.prefix(1)), color: Color.random(seed: friend.id ?? friend.name), size: 86)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        
                        VStack(spacing: 4) {
                            Text(friend.name)
                                .font(AppTypography.titleDisplay)
                                .foregroundColor(.primary)
                            
                            Text(friend.username)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Actions
                        HStack(spacing: AppSpacing.element) {
                            // Settle Up Button
                            if !repo.friendBalances.isEmpty {
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
                            }
                            
                            // Nudge Button (if they owe you)
                            if repo.friendBalances.values.contains(where: { $0 > 0.01 }) {
                                Button(action: sendNudge) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "hand.wave.fill")
                                        Text("Nudge")
                                    }
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.top, AppSpacing.compact)
                    }
                    .padding(.vertical, AppSpacing.section)
                    
                    
                    // Stats (Multi-Currency)
                    if !repo.friendBalances.isEmpty {
                        VStack(spacing: AppSpacing.element) {
                            ForEach(repo.friendBalances.sorted(by: { $0.value > $1.value }), id: \.key) { currency, amount in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(amount > 0 ? "OWES YOU" : "YOU OWE")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary)
                                        
                                        Text("\(currency) \(String(format: "%.2f", abs(amount)))")
                                            .font(AppTypography.prominentBalance) // Premium font
                                            .foregroundColor(amount > 0 ? .functionalSuccess : .functionalError)
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.medium)
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.bottom, AppSpacing.section)
                    } else if !repo.isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("All settled up!")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.section)
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                        .cornerRadius(AppRadius.medium)
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.bottom, AppSpacing.section)
                    }
                    
                    // Transactions List
                    VStack(alignment: .leading, spacing: AppSpacing.element) {
                        Text("History")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        VStack(spacing: AppSpacing.compact) {
                            if repo.isLoading && repo.friendTransactions.isEmpty {
                                ProgressView()
                                    .padding()
                            } else if repo.friendTransactions.isEmpty {
                                Text("No shared history yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(repo.friendTransactions) { transaction in
                                    FriendCardRow(transaction: transaction)
                                        .onTapGesture {
                                            selectedTransaction = transaction
                                        }
                                        .contextMenu {
                                             Button(role: .destructive) {
                                                 deleteTransaction(transaction)
                                             } label: {
                                                 Label("Delete", systemImage: "trash")
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
                    loadData()
                }
        }
        .sheet(item: $selectedTransaction) { tx in
             if let req = reconstructRequest(from: tx) {
                SplitRequestDetailView(request: req)
                    .presentationDetents([.fraction(0.6)])
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
    
    // Reconstruct Helper
    private func reconstructRequest(from tx: FirestoreModels.Transaction) -> FirestoreModels.SplitRequest? {
        guard let id = tx.id else { return nil }
        let status = FirestoreModels.SplitRequest.RequestStatus(rawValue: tx.note ?? "") ?? .pending
        
        return FirestoreModels.SplitRequest(
            id: id,
            transactionId: id,
            groupId: nil,
            fromUid: tx.type == "income" ? appState.currentUserId : (friend.id ?? ""),
            toUid: tx.type == "income" ? (friend.id ?? "") : appState.currentUserId,
            fromName: tx.type == "income" ? "You" : friend.name,
            amount: tx.amount,
            currency: nil,
            note: tx.title,
            status: status,
            dependencyId: nil,
            lastNudgedAt: nil,
            createdAt: tx.date
        )
    }
    
    private func undoToggle() {
        // Implement if we decide to add Toggle to the list (currently removed in favor of simple history, 
        // as pending items are best managed in Group/Home or specific request view.
        // But user had it, so let's support it if we add the button back or swipe.)
        // For now, leaving empty or implementing swipe logic.
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.Transaction) {
        // Same as before
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

// MARK: - Components (Specific to Friend View)

struct FriendCardRow: View {
    let transaction: FirestoreModels.Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: transaction.colorHex).opacity(0.1))
                    .frame(width: 46, height: 46)
                Image(systemName: transaction.icon)
                    .font(.system(size: 20)) // Slightly larger
                    .foregroundColor(Color(hex: transaction.colorHex))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(transaction.subtitle ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text((transaction.type == "income" ? "+" : "") + String(format: "$%.2f", abs(transaction.amount)))
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(transaction.type == "income" ? .functionalSuccess : .primary)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
    }
}
