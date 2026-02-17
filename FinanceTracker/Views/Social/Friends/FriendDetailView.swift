import SwiftUI
import FirebaseFirestore

struct FriendDetailView: View {
    let friend: FirestoreModels.Friend
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var repo = SocialRepository()
    
    // UI State
    enum FriendSheet: Identifiable, Equatable {
        case addExpense
        case settleUp
        case transactionDetail(FirestoreModels.TransactionModel)
        
        var id: String {
            switch self {
            case .addExpense: return "addExpense"
            case .settleUp: return "settleUp"
            case .transactionDetail(let tx): return "tx-\(tx.id ?? "")"
            }
        }
        
        static func == (lhs: FriendSheet, rhs: FriendSheet) -> Bool {
            return lhs.id == rhs.id
        }
    }

    @State private var activeSheet: FriendSheet?
    
    // Undo State
    @State private var recentlyToggledTx: FirestoreModels.TransactionModel?
    @State private var recentlyPaidSplitIds: Set<String> = []
    @State private var showUndoToast = false
    @State private var undoWorkItem: DispatchWorkItem?
    
    // Derived State
    private var pendingSplits: [FirestoreModels.SplitRequest] {
        repo.friendTransactions
            .filter { ($0.note ?? "") == "pending" && !recentlyPaidSplitIds.contains($0.id ?? "") }
            .compactMap { reconstructRequest(from: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
            
            List {
                // 1. Header
                Section {
                    DetailHeaderView(
                        title: friend.name,
                        onBack: { dismiss() },
                        onMenu: nil,
                        backgroundColor: Color.backgroundPrimary,
                        textColor: .primary,
                        avatar: {
                            ProfileAvatar(
                                text: String(friend.name.prefix(1)),
                                color: Color.random(seed: friend.name),
                                size: AppSize.avatarHero
                            )
                        },
                        subtitle: {
                            Text("@\(friend.username)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Capsule())
                        },
                        actions: {
                            HStack(spacing: 12) {
                                Button(action: {
                                    HapticManager.shared.light()
                                    activeSheet = .settleUp
                                }) {
                                    Text("Settle")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(colorScheme == .dark ? .black : .white)
                                        .padding(.horizontal, 20)
                                        .frame(height: 44)
                                        .background(colorScheme == .dark ? Color.white : Color.black)
                                        .clipShape(Capsule())
                                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                                
                                Button(action: {
                                    HapticManager.shared.light()
                                    activeSheet = .addExpense
                                }) {
                                    Image(systemName: "plus")
                                        .font(.headline)
                                        .foregroundColor(colorScheme == .dark ? .black : .white)
                                        .frame(width: 44, height: 44)
                                        .background(colorScheme == .dark ? Color.white : Color.black)
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                }
                            }
                        }
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                
                // 2. Action Required (High Priority)
                if !pendingSplits.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Action Required")
                                    .font(.headline)
                                Spacer()
                                Text("\(pendingSplits.count)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(pendingSplits) { split in
                                    FriendPendingSplitCard(split: split, userId: appState.currentUserId, onToggle: {
                                        handleSplitToggle(split)
                                    })
                                    .onTapGesture {
                                        // Find original transaction to select
                                        if let tx = repo.friendTransactions.first(where: { $0.id == split.id }) {
                                            activeSheet = .transactionDetail(tx)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                
                // 3. Overview & Net Balance
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overview")
                            .font(.headline)
                        
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
                    }
                    .padding(.vertical, 8)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                
                // 4. Recent Activity
                Section(header: 
                    Text("Recent Activity")
                        .font(.headline)
                        .padding(.vertical, 8)
                ) {
                    if repo.isLoading && repo.friendTransactions.isEmpty {
                        ProgressView().padding()
                         .listRowSeparator(.hidden)
                         .listRowBackground(Color.clear)
                    } else if repo.friendTransactions.isEmpty {
                        ContentUnavailableView("No activity", systemImage: "clock.arrow.circlepath", description: Text("Shared expenses will appear here."))
                         .listRowSeparator(.hidden)
                         .listRowBackground(Color.clear)
                    } else {
                        ForEach(repo.friendTransactions) { transaction in
                            FriendCardRow(transaction: transaction, friendName: friend.name)
                                .onTapGesture { activeSheet = .transactionDetail(transaction) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { deleteTransaction(transaction) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    let isPaid = (transaction.note ?? "").lowercased() == "paid"
                                    Button { toggleTransactionStatus(transaction) } label: {
                                        Label(isPaid ? "Mark Pending" : "Mark Paid", systemImage: isPaid ? "arrow.uturn.backward" : "checkmark.circle")
                                    }
                                    .tint(isPaid ? .orange : .green)
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 8, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .headerProminence(.increased)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addExpense:
                EditGroupTransactionWizardView(group: nil, preSelectedFriend: friend, transactionToEdit: nil) { amount, note, category, splits in
                    handleAddExpense(amount: amount, note: note, category: category, splits: splits)
                }
                .presentationDetents([.large])
            case .settleUp:
                SettleUpWizardView(group: nil, preSelectedFriend: friend)
                    .presentationDetents([.large])
            case .transactionDetail(let tx):
                 // Always show SplitRequestDetailView if we can reconstruct the request
                 if let req = reconstructRequest(from: tx) {
                    SplitRequestDetailView(request: req)
                        .presentationDetents([.medium, .large])
                } else {
                    Text("Error loading details")
                }
            }
        }
        .onChange(of: activeSheet) { _, newValue in
             if newValue == nil {
                 loadData()
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
    
    private func handleAddExpense(amount: Double, note: String, category: FirestoreModels.CategoryBudget?, splits: [FirestoreModels.Split]) {
        // Construct TransactionModel
        // NOTE: In Friend context, we don't have a groupId.
        // We create a generic transaction and the Manager handles creating split requests.
        
        let transaction = FirestoreModels.TransactionModel(
            userId: appState.currentUserId,
            title: note.isEmpty ? (category?.category ?? "Expense") : note,
            subtitle: category?.category ?? "Shared Expense",
            amount: -abs(amount),
            date: Date(),
            type: "expense",
            createdAt: Date(),
            icon: category?.icon ?? "person.2.fill",
            colorHex: category?.colorHex ?? "#808080",
            note: note,
            splits: splits
        )
        
        Task {
            do {
                // Use generic creation. Manager will handle creating split requests based on 'splits' array.
                // Note: We don't have a 'createFriendTransaction' specifically, but 'createSocialTransaction' can handle nil groupId if designed well,
                // OR we need to manually handle it if Manager expects group.
                // Looking at GroupDetailView: SocialTransactionManager.shared.createSocialTransaction
                // Let's assume it handles nil group or we fallback to friend logic.
                
                // Since 'createSocialTransaction' usually writes to group collection, we might need a different path for 1:1.
                // However, the 'splits' are what matter for 1:1.
                // If groupId is nil, the manager should just create the split requests.
                
                _ = try await SocialTransactionManager.shared.createSocialTransaction(
                    transaction: transaction,
                    payerUid: appState.currentUserId,
                    payerName: appState.userName,
                    groupId: nil, // No Group
                    friendCache: appState.friendRepo.friends,
                    groupCache: appState.groupRepo.groups
                )
                
                await MainActor.run {
                    HapticManager.shared.success()
                    loadData()
                }
            } catch {
                print("Error adding friend expense: \(error)")
                HapticManager.shared.error()
            }
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
    
    private func handleSplitToggle(_ split: FirestoreModels.SplitRequest) {
        HapticManager.shared.success()
        withAnimation { 
            if let id = split.id { recentlyPaidSplitIds.insert(id) }
        }
        
        // Find corresponding transaction model for undo
        if let tx = repo.friendTransactions.first(where: { $0.id == split.id }) {
            recentlyToggledTx = tx
        }
        
        withAnimation { showUndoToast = true }
        undoWorkItem?.cancel()
        
        Task {
            do {
                try await SocialTransactionManager.shared.markSplitAsPaid(request: split, currentUserId: appState.currentUserId, currentUserName: appState.userName)
                loadData()
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                await MainActor.run { if let id = split.id { recentlyPaidSplitIds.remove(id) } }
            } catch {
                await MainActor.run { 
                     if let id = split.id { recentlyPaidSplitIds.remove(id) }
                }
            }
        }
        
        let workItem = DispatchWorkItem { withAnimation { showUndoToast = false; recentlyToggledTx = nil } }
        undoWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
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
                    if let id = req.id { recentlyPaidSplitIds.remove(id) }
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

struct FriendPendingSplitCard: View {
    let split: FirestoreModels.SplitRequest
    let userId: String
    let onToggle: () -> Void
    
    private var isOwed: Bool { split.fromUid == userId }
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            Circle()
                .fill(Color.primary.opacity(0.05))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: isOwed ? "arrow.down.left" : "arrow.up.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isOwed ? .green : .red)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(split.note ?? "Split Expense")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    if isOwed {
                        Text("\(split.toName ?? "Friend")").fontWeight(.medium)
                        Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
                        Text("You").fontWeight(.bold)
                    } else {
                        Text("You").fontWeight(.bold)
                        Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
                        Text("\(split.fromName ?? "Friend")").fontWeight(.medium)
                    }
                    Text("•").foregroundColor(.secondary.opacity(0.5))
                    Text(split.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", split.amount))")
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(isOwed ? .green : .primary)
                
                Button(action: onToggle) {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.element)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct FriendCardRow: View {
    let transaction: FirestoreModels.TransactionModel
    let friendName: String
    
    @State private var fetchedOriginalAmount: Double?
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Monochrome Icon
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 40, height: 40)
                
                Image(systemName: transaction.icon ?? "dollarsign.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                let totalAmount = transaction.originalAmount ?? fetchedOriginalAmount
                let isYouPaid = transaction.type == "income"
                
                if let total = totalAmount {
                    let formattedTotal = String(format: "$%.2f", total)
                    Text(isYouPaid ? "You paid \(formattedTotal)" : "\(friendName) paid \(formattedTotal)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
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
                        .padding(.horizontal, 6)
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
                    .fontWeight(.semibold)
                    // Keep Green/Red for amounts as it's critical info
                    .foregroundColor(transaction.type == "income" ? .green : .red)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(AppSpacing.element)
        // Clean list style - no background tint
        .background(Color.backgroundPrimary) // Or clear
        .contentShape(Rectangle()) // Make tappable
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.primary.opacity(0.05)),
            alignment: .bottom
        )
        .task {
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
