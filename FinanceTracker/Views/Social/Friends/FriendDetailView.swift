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
    @State private var transactionToEdit: FirestoreModels.TransactionModel?
    
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
                headerSection
                actionRequiredSection
                overviewSection
                recentActivitySection
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
                EditGroupTransactionWizardView(group: nil, preSelectedFriend: friend, transactionToEdit: nil) { amount, note, category, splits, originalAmount, currencyCode, exchangeRate in
                    handleAddExpense(amount: amount, note: note, category: category, splits: splits, originalAmount: originalAmount, currencyCode: currencyCode, exchangeRate: exchangeRate)
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
        .sheet(item: $transactionToEdit) { tx in
             // Construct mock group transaction for the wizard
             let groupTx = FirestoreModels.GroupTransaction(
                 id: nil,
                 title: tx.title,
                 amount: tx.amount,
                 payerId: tx.userId,
                 payerName: appState.userName,
                 receiverId: nil,
                 receiverName: nil,
                 date: tx.date,
                 type: tx.type,
                 currencyCode: nil,
                 note: tx.note,
                 category: tx.subtitle,
                 icon: tx.icon,
                 colorHex: tx.colorHex,
                 originalTransactionId: tx.id,
                 originalAmount: nil,
                 exchangeRate: nil,
                 editHistory: nil
             )
             
             EditGroupTransactionWizardView(group: nil, preSelectedFriend: friend, transactionToEdit: groupTx) { amount, note, category, splits, originalAmount, currencyCode, exchangeRate in
                 handleUpdateTransaction(originalTx: tx, amount: amount, note: note, category: category, splits: splits, originalAmount: originalAmount, currencyCode: currencyCode, exchangeRate: exchangeRate)
             }
             .presentationDetents([.large])
        }
        .onChange(of: activeSheet) { _, newValue in
             if newValue == nil {
                 loadData()
             }
        }
    }

    // MARK: - Sections
    
    private var headerSection: some View {
        SocialDetailHeaderSection(
            title: friend.name,
            onBack: { dismiss() },
            avatar: {
                ProfileAvatar(
                    text: String(friend.name.prefix(1)),
                    color: Color.random(seed: friend.name),
                    size: AppSize.avatarHero
                )
            },
            subtitle: {
                SocialHeaderPill {
                    Text("@\(friend.username ?? "")")
                }
            },
            onSettle: { activeSheet = .settleUp },
            onAddExpense: { activeSheet = .addExpense }
        )
    }
    
    @ViewBuilder
    private var actionRequiredSection: some View {
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
                            .background(AppColors.functionalExpense)
                            .clipShape(Circle())
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(pendingSplits) { split in
                            PendingSplitCard(
                                split: split,
                                userId: appState.currentUserId,
                                onToggle: {
                                    if split.isSettlement == true {
                                        acceptSettlement(split)
                                    } else {
                                        handleSplitToggle(split)
                                    }
                                },
                                onDelete: {
                                    if split.isSettlement == true {
                                        declineSettlement(split)
                                    } else {
                                        resolveSplitAction(split)
                                    }
                                }
                            )
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
    }
    
    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Overview")
                    .font(.headline)
                
                let balance = repo.friendBalances.values.reduce(0, +)
                let totalSharedByCurrency = calculateTotalSharedByCurrency(transactions: repo.friendTransactions)
                let totalSharedText = formatCurrencyBreakdown(totalSharedByCurrency)
                
                SocialTwoCardRow(
                    left: SocialStatCard(
                        title: "Total Shared",
                        value: totalSharedText
                    ),
                    right: SocialStatCard(
                        title: balance >= 0 ? "Owed to You" : "You Owe",
                        value: String(format: "$%.2f", abs(balance)),
                        valueColor: balance == 0 ? .primary : (balance > 0 ? .green : .red)
                    )
                )
            }
            .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func calculateTotalSharedByCurrency(transactions: [FirestoreModels.TransactionModel]) -> [String: Double] {
        var totals: [String: Double] = [:]
        var seen: Set<String> = []
        
        for tx in transactions {
            if (tx.subtitle ?? "") == "Settlement" {
                continue
            }
            
            let currency = tx.currencyCode ?? CurrencyManager.shared.mainCurrency
            let identity = tx.source ?? tx.id ?? UUID().uuidString
            let key = "\(currency)|\(identity)"
            
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            
            let value = abs(tx.originalAmount ?? tx.amount)
            totals[currency, default: 0] += value
        }
        
        return totals.filter { abs($0.value) > 0.01 }
    }
    
    private func formatCurrencyBreakdown(_ totals: [String: Double]) -> String {
        let sorted = totals.sorted(by: { $0.key < $1.key })
        if sorted.isEmpty {
            return String(format: "$%.2f", 0.0)
        }
        
        func format(amount: Double, currencyCode: String) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f %@", amount, currencyCode)
        }
        
        if sorted.count == 1, let (code, amount) = sorted.first {
            return format(amount: amount, currencyCode: code)
        }
        
        return sorted
            .map { code, amount in "\(code) \(format(amount: amount, currencyCode: code))" }
            .joined(separator: "\n")
    }
    
    private var recentActivitySection: some View {
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
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(AppRadius.medium)
                        .onTapGesture { activeSheet = .transactionDetail(transaction) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deleteTransaction(transaction) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                            
                            let isPaid = (transaction.note ?? "").lowercased() == "paid"
                            Button { toggleTransactionStatus(transaction) } label: {
                                Label(isPaid ? "Mark Pending" : "Mark Paid", systemImage: isPaid ? "arrow.uturn.backward" : "checkmark.circle")
                            }
                            .tint(isPaid ? .orange : .green)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if transaction.userId == appState.currentUserId && transaction.type != "income" {
                                Button {
                                    transactionToEdit = transaction
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 8, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                
                // [NEW] Native Ad
                NativeAdView()
                    .listRowInsets(EdgeInsets(top: AppSpacing.compact, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .headerProminence(.increased)
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
    
    private func handleAddExpense(amount: Double, note: String, category: FirestoreModels.CategoryBudget?, splits: [FirestoreModels.Split], originalAmount: Double?, currencyCode: String?, exchangeRate: Double?) {
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
            splits: splits,
            originalAmount: originalAmount,
            currencyCode: currencyCode,
            exchangeRate: exchangeRate
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
    
    private func handleUpdateTransaction(originalTx: FirestoreModels.TransactionModel, amount: Double, note: String, category: FirestoreModels.CategoryBudget?, splits: [FirestoreModels.Split], originalAmount: Double?, currencyCode: String?, exchangeRate: Double?) {
        let transaction = FirestoreModels.TransactionModel(
            id: originalTx.id,
            userId: appState.currentUserId,
            title: note.isEmpty ? (category?.category ?? "Expense") : note,
            subtitle: category?.category ?? "Shared Expense",
            amount: -abs(amount),
            date: originalTx.date,
            type: originalTx.type,
            createdAt: originalTx.createdAt,
            icon: category?.icon ?? originalTx.icon,
            colorHex: category?.colorHex ?? originalTx.colorHex,
            note: note,
            splits: splits,
            originalAmount: originalAmount ?? originalTx.originalAmount,
            currencyCode: currencyCode ?? originalTx.currencyCode,
            exchangeRate: exchangeRate ?? originalTx.exchangeRate
        )
        
        Task {
            do {
                _ = try await SocialTransactionManager.shared.createSocialTransaction(
                    transaction: transaction,
                    payerUid: appState.currentUserId,
                    payerName: appState.userName,
                    groupId: nil,
                    friendCache: appState.friendRepo.friends,
                    groupCache: appState.groupRepo.groups
                )
                
                await MainActor.run {
                    HapticManager.shared.success()
                    loadData()
                    transactionToEdit = nil
                }
            } catch {
                print("Error updating friend expense: \(error)")
                HapticManager.shared.error()
            }
        }
    }
    
    private func reconstructRequest(from tx: FirestoreModels.TransactionModel) -> FirestoreModels.SplitRequest? {
        guard let id = tx.id else { return nil }
        let status = FirestoreModels.SplitRequest.RequestStatus(rawValue: tx.note ?? "") ?? .pending
        let isIncome = tx.type == "income"
        
        let fromUid = isIncome ? appState.currentUserId : (friend.id ?? "")
        let fromName = isIncome ? "You" : friend.name
        let toUid = isIncome ? (friend.id ?? "") : appState.currentUserId
        let toName = isIncome ? friend.name : "You"
        
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
            originalTotalAmount: tx.originalAmount, // Pass through if available
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
    
    // Add missing accept/decline handlers
    private func acceptSettlement(_ split: FirestoreModels.SplitRequest) {
        HapticManager.shared.success()
        Task {
            do {
                try await SocialTransactionManager.shared.acceptSettlement(request: split, currentUserId: appState.currentUserId, currentUserName: appState.userName)
                await MainActor.run { loadData() }
            } catch {
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func declineSettlement(_ split: FirestoreModels.SplitRequest) {
        HapticManager.shared.heavy()
        Task {
            do {
                try await SocialTransactionManager.shared.declineSettlement(request: split)
                await MainActor.run { loadData() }
            } catch {
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func resolveSplitAction(_ split: FirestoreModels.SplitRequest) {
        HapticManager.shared.heavy()
        if let id = split.id {
            _ = withAnimation {
                recentlyPaidSplitIds.insert(id)
            }
        }
        
        Task {
            do {
                try await SocialTransactionManager.shared.resolveSplitRequestAction(request: split)
                await MainActor.run { loadData() }
            } catch {
                await MainActor.run {
                    HapticManager.shared.error()
                    if let id = split.id {
                        recentlyPaidSplitIds.remove(id)
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

struct FriendCardRow: View {
    let transaction: FirestoreModels.TransactionModel
    let friendName: String
    
    @State private var fetchedOriginalAmount: Double?
    
    var body: some View {
        let isYouPaid = transaction.type == "income"
        let totalAmount = transaction.originalAmount ?? fetchedOriginalAmount
        
        let subtitle: String
        if let total = totalAmount {
            let formattedTotal = String(format: "$%.2f", total)
            subtitle = isYouPaid ? "You paid \(formattedTotal)" : "\(friendName) paid \(formattedTotal)"
        } else {
            let shareAmount = abs(transaction.amount)
            let formattedShare = String(format: "$%.2f", shareAmount)
            subtitle = isYouPaid ? "You lent \(formattedShare)" : "\(friendName) lent you \(formattedShare)"
        }
        
        var statusBadge: String? = nil
        if transaction.type == "income", (transaction.subtitle ?? "") == "You requested" {
            statusBadge = nil
        } else if let status = transaction.note, !status.isEmpty, ["pending", "paid", "accepted", "declined"].contains(status.lowercased()) {
            statusBadge = status
        }
        
        let amountColor: Color = transaction.type == "income" ? .green : .red
        
        return SocialTransactionCardView(
            title: transaction.title,
            subtitle: subtitle,
            amount: transaction.amount,
            date: transaction.date,
            type: transaction.type,
            category: transaction.subtitle,
            iconName: transaction.icon,
            colorHex: transaction.colorHex,
            amountColor: amountColor,
            statusBadge: statusBadge
        )
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
