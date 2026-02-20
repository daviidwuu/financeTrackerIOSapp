import SwiftUI
import FirebaseFirestore

struct GroupDetailView: View {
    let groupId: String
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var repo = SocialRepository()
    
    // Computed group property from appState
    var group: FirestoreModels.Group? {
        appState.groupRepo.groups.first(where: { $0.id == groupId })
    }
    
    // UI State
    enum GroupSheet: Identifiable, Equatable {
        case addExpense
        case settings
        case settleUp
        case members
        case simplification
        case splitDetail(FirestoreModels.SplitRequest)
        case transactionDetail(FirestoreModels.GroupTransaction)
        
        var id: String {
            switch self {
            case .addExpense: return "addExpense"
            case .settings: return "settings"
            case .settleUp: return "settleUp"
            case .members: return "members"
            case .simplification: return "simplification"
            case .splitDetail(let split): return "split-\(split.id ?? "")"
            case .transactionDetail(let tx): return "tx-\(tx.id ?? "")"
            }
        }
        
        static func == (lhs: GroupSheet, rhs: GroupSheet) -> Bool {
            return lhs.id == rhs.id
        }
    }

    @State private var activeSheet: GroupSheet?
    @State private var transactionToEdit: FirestoreModels.GroupTransaction?
    @State private var requestToAccept: FirestoreModels.SplitRequest? // Added for accept flow
    @State private var groupBalances: [String: [String: Double]] = [:] // FIX 1.3: currency → (memberId → balance)
    
    // Feature State
    @State private var pendingSplits: [FirestoreModels.SplitRequest] = []
    @State private var debtInstructions: [DebtInstruction] = []
    
    // Undo State
    @State private var recentlyPaidSplit: FirestoreModels.SplitRequest?
    @State private var recentlyPaidSplitIds: Set<String> = [] 
    @State private var showUndoToast = false
    @State private var undoWorkItem: DispatchWorkItem?
    @State private var splitToDelete: FirestoreModels.SplitRequest?
    @State private var showLeaveGroupDialog = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
            
            if let group = group {
                List {
                    // 1. Header
                    GroupHeaderSection(
                        group: group,
                        onBack: { dismiss() },
                        onSettings: { activeSheet = .settings },
                        onMembers: { activeSheet = .members },
                        onSettle: { activeSheet = .settleUp },
                        onAddExpense: { activeSheet = .addExpense },
                        onLeaveGroup: { showLeaveGroupDialog = true }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    
                    // 2. Pending Actions (High Priority) — Split by role
                    let receiverSplits = pendingSplits.filter { $0.toUid == appState.currentUserId }
                    let senderSplits = pendingSplits.filter { $0.fromUid == appState.currentUserId }
                    
                    // 2a. Splits I need to respond to
                    if !receiverSplits.isEmpty {
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    Text("Action Required")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(receiverSplits.count)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(AppColors.functionalExpense)
                                        .clipShape(Circle())
                                }
                                
                                VStack(spacing: 12) {
                                    ForEach(receiverSplits) { split in
                                        PendingSplitCard(split: split, userId: appState.currentUserId, onToggle: {
                                            requestToAccept = split // Open wizard instead of marking paid
                                        }, onDelete: {
                                            splitToDelete = split
                                        })
                                        .onTapGesture { activeSheet = .splitDetail(split) }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    
                    // 2b. Splits I sent (waiting for response)
                    if !senderSplits.isEmpty {
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                    .foregroundColor(.blue)
                                    Text("Your Requests")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(senderSplits.count)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                }
                                
                                VStack(spacing: 12) {
                                    ForEach(senderSplits) { split in
                                        PendingSplitCard(split: split, userId: appState.currentUserId, onToggle: {
                                            handleSplitToggle(split)
                                        }, onDelete: {
                                            splitToDelete = split
                                        }, onNudge: {
                                            Task {
                                                try? await SocialTransactionManager.shared.nudgeSplitRequest(request: split)
                                                HapticManager.shared.success()
                                            }
                                        })
                                        .onTapGesture { activeSheet = .splitDetail(split) }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) { deleteSplit(split) } label: {
                                                Label("Cancel", systemImage: "trash")
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
                    
                    // 3. Group Overview & Stats (Consolidated)
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Overview")
                                .font(.headline)
                            
                            let expenses = repo.groupTransactions.filter { $0.type != "settlement" }
                            let totalSpend = abs(expenses.reduce(0) { $0 + $1.amount })
                            
                            // Calculate Personal Liability (Net Outflow)
                            // Formula: (Expenses I Paid) + (Settlements I Paid) - (Settlements I Received)
                            let myExpensesPaid = abs(expenses.filter { $0.payerId == appState.currentUserId }.reduce(0) { $0 + $1.amount })
                            
                            let settlements = repo.groupTransactions.filter { $0.type == "settlement" }
                            let settlementsPaid = abs(settlements.filter { $0.payerId == appState.currentUserId }.reduce(0) { $0 + $1.amount })
                            let settlementsReceived = abs(settlements.filter { 
                                if let rid = $0.receiverId {
                                    return rid == appState.currentUserId
                                }
                                return $0.receiverName == appState.userName 
                            }.reduce(0) { $0 + $1.amount })
                            
                            let myNetExpenses = myExpensesPaid + settlementsPaid - settlementsReceived
                            
                            // Overview Cards
                            HStack(spacing: 12) {
                                // Card 1: Total Expenses
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Expenses")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "$%.2f", totalSpend))
                                        .font(AppTypography.sectionHeader)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.medium)
                                
                                // Card 2: My Expenses
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("My Expenses")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "$%.2f", myNetExpenses))
                                        .font(AppTypography.sectionHeader)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.medium)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    // 4. Balances (Who owes who) — FIX 1.3: Per-currency
                    let hasAnyBalance = groupBalances.values.contains { currencyBalances in
                        currencyBalances.contains { abs($0.value) > 0.01 }
                    }
                    if hasAnyBalance {
                        Section {
                            VStack(alignment: .leading, spacing: AppSpacing.element) {
                                HStack {
                                    Text("Balances")
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                ForEach(Array(groupBalances.keys.sorted()), id: \.self) { currency in
                                    if let currencyBalances = groupBalances[currency] {
                                        let nonZeroBalances = currencyBalances.filter { abs($0.value) > 0.01 }
                                        if !nonZeroBalances.isEmpty {
                                            if groupBalances.keys.count > 1 {
                                                Text(currency)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, 4)
                                            }
                                            
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 12) {
                                                    let memberIds = nonZeroBalances.keys.sorted()
                                                    ForEach(memberIds, id: \.self) { memberId in
                                                        if let bal = nonZeroBalances[memberId] {
                                                            BalanceCard(
                                                                name: getMemberName(id: memberId, group: group),
                                                                amount: abs(bal),
                                                                isOwed: bal > 0,
                                                                isSelf: memberId == appState.currentUserId,
                                                                currency: currency
                                                            )
                                                        }
                                                    }
                                                }
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
                    
                    // 5. Activity Feed
                    Section(header: 
                        Text("Recent Activity")
                            .font(.headline)
                            .padding(.vertical, 8)
                    ) {
                        if repo.isLoading && repo.groupTransactions.isEmpty {
                            ProgressView().padding()
                             .listRowSeparator(.hidden)
                             .listRowBackground(Color.clear)
                        } else if repo.groupTransactions.isEmpty {
                            ContentUnavailableView("No Activity", systemImage: "list.bullet.clipboard", description: Text("Transactions will appear here."))
                             .listRowSeparator(.hidden)
                             .listRowBackground(Color.clear)
                        } else {
                            ForEach(repo.groupTransactions.filter { $0.id != nil }) { transaction in
                                GroupTransactionRow(transaction: transaction, currentUserId: appState.currentUserId)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(AppRadius.medium)
                                    .onTapGesture { activeSheet = .transactionDetail(transaction) }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        // Only Payer can delete transactions (Expenses or Settlements)
                                        // This ensures data integrity. Receiver cannot delete Payer's record.
                                        if transaction.payerId == appState.currentUserId {
                                            Button(role: .destructive) { deleteTransaction(transaction, group: group) } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            .tint(.red)
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        if transaction.payerId == appState.currentUserId && transaction.type != "settlement" {
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
                        }
                    }
                    .headerProminence(.increased)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            } else {
                VStack {
                    ProgressView()
                    Text("Loading Group...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Undo Toast Overlay
            if showUndoToast {
                UndoToast(text: "Marked as paid", onUndo: undoPayment)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .confirmationDialog(
            "Delete Split",
            isPresented: Binding(
                get: { splitToDelete != nil },
                set: { if !$0 { splitToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Hide for me") {
                if let split = splitToDelete {
                    hideSplit(split)
                }
                splitToDelete = nil
            }
            Button("Cancel for everyone", role: .destructive) {
                if let split = splitToDelete {
                    deleteSplit(split)
                }
                splitToDelete = nil
            }
            Button("Never mind", role: .cancel) {
                splitToDelete = nil
            }
        } message: {
            Text("This split will be hidden from your view but remains active for others, or you can cancel it for everyone.")
        }
        .confirmationDialog(
            "Leave Group",
            isPresented: $showLeaveGroupDialog,
            titleVisibility: .visible
        ) {
            Button("Keep my data") {
                leaveGroup(keepData: true)
            }
            Button("Delete my data", role: .destructive) {
                leaveGroup(keepData: false)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your splits and transactions from this group will either be kept as personal records or permanently deleted.")
        }
        .onAppear { loadGroupData() }
        .sheet(item: $activeSheet) { sheet in
             // Using a ZStack to ensure context is available and stable
             ZStack {
                 if let group = group {
                     switch sheet {
                     case .addExpense:
                         EditGroupTransactionWizardView(group: group, preSelectedFriend: nil, transactionToEdit: transactionToEdit) { amount, note, category, splits in
                             handleAddExpense(amount: amount, note: note, category: category, splits: splits, group: group)
                         }
                         .presentationDetents([.large])
                     case .settings:
                         GroupCreationWizardView(groupToEdit: group)
                     case .settleUp:
                         SettleUpWizardView(group: group, preSelectedFriend: nil)
                             .presentationDetents([.large])
                     case .members:
                         GroupMembersView(group: group)
                             .presentationDetents([.medium, .large])
                     case .simplification:
                         VStack(spacing: 24) {
                             Text("Simplify Debts")
                                 .font(.title2)
                                 .fontWeight(.bold)
                                 .padding(.top, 24)
                             
                             Text("This plan minimizes the number of transactions needed to settle everyone up.")
                                 .font(.subheadline)
                                 .foregroundColor(.secondary)
                                 .multilineTextAlignment(.center)
                                 .padding(.horizontal)
                             
                             ScrollView {
                                 VStack(spacing: 12) {
                                     ForEach(debtInstructions) { instruction in
                                         DebtInstructionRow(
                                             debtorName: getMemberName(id: instruction.debtorId, group: group),
                                             creditorName: getMemberName(id: instruction.creditorId, group: group),
                                             amount: instruction.amount,
                                             currency: instruction.currency
                                         )
                                     }
                                 }
                                 .padding()
                             }
                         }
                         .presentationDetents([.medium, .large])
                     case .splitDetail(let split):
                         SplitRequestDetailView(request: split)
                     case .transactionDetail(let transaction):
                         GroupTransactionDetailView(transaction: transaction, group: group)
                             .presentationDetents([.medium, .large])
                             .presentationDragIndicator(.visible)
                     }
                 } else {
                     // Fallback if group is missing (rare but possible during sync)
                     ProgressView()
                 }
             }
        }
        .sheet(item: $transactionToEdit) { tx in
             if let group = group {
                 EditGroupTransactionWizardView(group: group, preSelectedFriend: nil, transactionToEdit: tx) { amount, note, category, splits in
                     handleUpdateTransaction(originalTx: tx, amount: amount, note: note, category: category, splits: splits, group: group)
                 }
                 .presentationDetents([.large])
             }
        }
        .sheet(item: $requestToAccept) { request in
            AddTransactionView(requestToAccept: request, onSave: { transaction in
                 acceptRequest(request, transaction: transaction)
            })
        }
        .onChange(of: activeSheet) { _, newValue in
             // Reload data only when sheet is dismissed (becomes nil)
             if newValue == nil {
                 loadGroupData()
                 transactionToEdit = nil
             }
        }
        .onReceive(repo.$groupBalances) { newBalances in
             groupBalances = newBalances
             debtInstructions = repo.calculateDebtResolution(balances: newBalances)
        }
        .onReceive(repo.$myPendingGroupSplits) { newSplits in
             pendingSplits = newSplits.filter { 
                 guard let id = $0.id else { return false }
                 return !recentlyPaidSplitIds.contains(id) 
             }
        }
        .onDisappear {
            print("DEBUG: GroupDetailView onDisappear - Popped from stack")
        }
    }
    
    // Logic Functions (Same as before)
    private func loadGroupData() {
        repo.fetchGroupTransactions(groupId: groupId)
        repo.listenToGroupBalances(groupId: groupId, currentUserId: appState.currentUserId)
    }
    
    private func handleSplitToggle(_ split: FirestoreModels.SplitRequest) {
        HapticManager.shared.success()
        withAnimation { 
            pendingSplits.removeAll { $0.id == split.id } 
            if let id = split.id { recentlyPaidSplitIds.insert(id) }
        }
        recentlyPaidSplit = split
        withAnimation { showUndoToast = true }
        undoWorkItem?.cancel()
        Task {
            do {
                try await SocialTransactionManager.shared.markSplitAsPaid(request: split, currentUserId: appState.currentUserId, currentUserName: appState.userName)
                loadGroupData()
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                await MainActor.run { if let id = split.id { recentlyPaidSplitIds.remove(id) } }
            } catch {
                await MainActor.run { 
                    pendingSplits.append(split)
                    pendingSplits.sort { $0.createdAt > $1.createdAt }
                    if let id = split.id { recentlyPaidSplitIds.remove(id) }
                }
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
        withAnimation { 
            pendingSplits.append(split)
            pendingSplits.sort { $0.createdAt > $1.createdAt } 
            if let id = split.id { recentlyPaidSplitIds.remove(id) }
        }
        Task { try? await SocialTransactionManager.shared.unmarkSplitAsPaid(request: split, currentUserId: appState.currentUserId); loadGroupData() }
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.GroupTransaction, group: FirestoreModels.Group) {
        guard let groupId = group.id, let txId = transaction.id else {
            HapticManager.shared.error()
            return
        }
        HapticManager.shared.light()
        
        // Optimistic Update
        withAnimation {
            repo.groupTransactions.removeAll { $0.id == txId }
        }
        
        Task {
            do {
                // Use Manager to handle cascading delete (Splits, Original Tx, etc.)
                try await SocialTransactionManager.shared.deleteSocialTransaction(groupTransaction: transaction, groupId: groupId)
                await MainActor.run {
                    loadGroupData()
                }
            } catch {
                print("Error deleting transaction: \(error)")
                HapticManager.shared.error()
                // Revert optimistic update if needed? For now, loadGroupData will fix it.
                await MainActor.run { loadGroupData() }
            }
        }
    }
    
    private func deleteSplit(_ split: FirestoreModels.SplitRequest) {
        HapticManager.shared.heavy()
        
        // Optimistic Update
        withAnimation {
            pendingSplits.removeAll { $0.id == split.id }
        }
        
        Task {
            do {
                // Use the new resolver to handle Delete (Payer) or Decline (Receiver)
                try await SocialTransactionManager.shared.resolveSplitRequestAction(request: split)
                
                // Also force refresh repo to ensure consistency
                await MainActor.run { repo.listenToGroupBalances(groupId: groupId, currentUserId: appState.currentUserId) }
            } catch {
                await MainActor.run { 
                    HapticManager.shared.error()
                    // Revert
                    pendingSplits.append(split)
                }
            }
        }
    }
    
    private func hideSplit(_ split: FirestoreModels.SplitRequest) {
        guard let requestId = split.id else { return }
        HapticManager.shared.medium()
        
        // Optimistic Update
        withAnimation {
            pendingSplits.removeAll { $0.id == split.id }
        }
        
        Task {
            do {
                try await SocialTransactionManager.shared.hideSplitForUser(requestId: requestId, userId: appState.currentUserId)
                await MainActor.run { repo.listenToGroupBalances(groupId: groupId, currentUserId: appState.currentUserId) }
            } catch {
                await MainActor.run {
                    HapticManager.shared.error()
                    pendingSplits.append(split)
                }
            }
        }
    }
    
    private func leaveGroup(keepData: Bool) {
        guard let groupId = group?.id else { return }
        HapticManager.shared.heavy()
        
        Task {
            do {
                try await appState.groupRepo.leaveGroup(groupId: groupId, userId: appState.currentUserId, keepData: keepData)
                await MainActor.run {
                    HapticManager.shared.success()
                    dismiss()
                }
            } catch {
                print("Error leaving group: \(error)")
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    func getMemberName(id: String, group: FirestoreModels.Group) -> String {
        if id == appState.currentUserId { return "You" }
        if let friend = appState.friendRepo.friends.first(where: { $0.id == id }) { return friend.name }
        if let guest = appState.guestRepo.guests.first(where: { $0.id == id }) { return guest.name }
        if let name = group.memberNames?[id] { return name }
        return "Member"
    }
    
    private func handleAddExpense(amount: Double, note: String, category: FirestoreModels.CategoryBudget?, splits: [FirestoreModels.Split], group: FirestoreModels.Group) {
        let transaction = FirestoreModels.TransactionModel(
            userId: appState.currentUserId,
            title: note.isEmpty ? (category?.category ?? "Group Expense") : note,
            subtitle: category?.category ?? "Group: \(group.name)",
            amount: -abs(amount),
            date: Date(),
            type: "expense",
            createdAt: Date(),
            icon: category?.icon ?? "person.2.fill", // Or group icon
            colorHex: category?.colorHex ?? group.color,
            note: note,
            splits: splits
        )
        
        Task {
            do {
                _ = try await SocialTransactionManager.shared.createSocialTransaction(
                    transaction: transaction,
                    payerUid: appState.currentUserId,
                    payerName: appState.userName,
                    groupId: group.id,
                    friendCache: appState.friendRepo.friends,
                    groupCache: appState.groupRepo.groups
                )
                
                await MainActor.run {
                    HapticManager.shared.success()
                    loadGroupData()
                }
            } catch {
                print("Error adding group expense: \(error)")
                HapticManager.shared.error()
            }
        }
    }
    
    private func handleUpdateTransaction(originalTx: FirestoreModels.GroupTransaction, amount: Double, note: String, category: FirestoreModels.CategoryBudget?, splits: [FirestoreModels.Split], group: FirestoreModels.Group) {
        // Use the original source ID to ensure we update the existing transaction
        let txId = originalTx.originalTransactionId ?? originalTx.id
        
        let transaction = FirestoreModels.TransactionModel(
            id: txId,
            userId: appState.currentUserId,
            title: note.isEmpty ? (category?.category ?? "Group Expense") : note,
            subtitle: category?.category ?? "Group: \(group.name)",
            amount: -abs(amount),
            date: originalTx.date, // Keep original date
            type: originalTx.type,
            createdAt: originalTx.date,
            icon: category?.icon ?? originalTx.icon,
            colorHex: category?.colorHex ?? originalTx.colorHex,
            note: note,
            splits: splits
        )
        
        Task {
            do {
                _ = try await SocialTransactionManager.shared.createSocialTransaction(
                    transaction: transaction,
                    payerUid: appState.currentUserId,
                    payerName: appState.userName,
                    groupId: group.id,
                    friendCache: appState.friendRepo.friends,
                    groupCache: appState.groupRepo.groups
                )
                
                await MainActor.run {
                    HapticManager.shared.success()
                    loadGroupData()
                    transactionToEdit = nil
                }
            } catch {
                print("Error updating group expense: \(error)")
                HapticManager.shared.error()
            }
        }
    }
    
    // MARK: - Request Logic (Accept Flow matches HomeView)
    
    private func acceptRequest(_ request: FirestoreModels.SplitRequest, transaction: TransactionFormData) {
        // 1. Add the transaction
        addTransaction(transaction)
        
        // 2. Update Request Status
        Task {
            do {
                guard let id = request.id else { return }
                try await appState.requestRepo.updateRequestStatus(userId: appState.currentUserId, requestId: id, status: .accepted, lastUpdatedBy: appState.currentUserId)
                await MainActor.run {
                    // Optimistic update to remove it from action required
                    pendingSplits.removeAll { $0.id == id }
                }
            } catch {
                print("Failed to accept request: \(error)")
            }
        }
    }
    
    private func addTransaction(_ transaction: TransactionFormData) {
        Task {
            do {
                // Convert UI Transaction to Firestore Transaction
                let amount = CurrencyInput.parseOrZero(transaction.amount)
                let firestoreTransaction = FirestoreModels.TransactionModel(
                    userId: appState.currentUserId, // Use global user ID
                    title: transaction.title,
                    subtitle: transaction.subtitle,
                    amount: amount,
                    date: transaction.date,
                    type: amount < 0 ? "expense" : "income",
                    createdAt: Date(),
                    icon: transaction.icon,
                    colorHex: transaction.color.toHex() ?? "#000000",
                    note: transaction.notes,
                    originalAmount: transaction.originalAmount,
                    currencyCode: transaction.currencyCode,
                    exchangeRate: transaction.exchangeRate
                )
                try await appState.transactionRepo.addTransaction(firestoreTransaction)
                
                // Send notification after successful save
                NotificationManager.shared.sendTransactionNotification(
                    amount: amount,
                    category: transaction.title,
                    type: transaction.type,
                    originalAmount: transaction.originalAmount,
                    currencyCode: transaction.currencyCode
                )
            } catch {
                print("Failed to add transaction: \(error)")
            }
        }
    }
}

// MARK: - Subviews

struct GroupHeaderSection: View {
    let group: FirestoreModels.Group
    let onBack: () -> Void
    let onSettings: () -> Void
    let onMembers: () -> Void
    let onSettle: () -> Void
    let onAddExpense: () -> Void
    let onLeaveGroup: () -> Void
    
    var body: some View {
        Section {
            DetailHeaderView(
                title: group.name,
                onBack: onBack,
                onMenu: onSettings,
                backgroundColor: Color.backgroundPrimary,
                textColor: .primary,
                avatar: {
                    GroupAvatar(
                        icon: group.icon,
                        color: group.color,
                        size: AppSize.avatarHero
                    )
                },
                subtitle: {
                    Button(action: onMembers) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                            Text("\(group.members.count) members")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.borderless)
                },
                actions: {
                    HStack(spacing: 12) {
            Button(action: {
                HapticManager.shared.light()
                onSettle()
            }) {
                Text("Settle")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color.backgroundPrimary)
                    .padding(.horizontal, AppSpacing.margin)
                    .frame(height: 44)
                    .background(Color.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
                        
                        Button(action: {
                            HapticManager.shared.light()
                            onAddExpense()
                        }) {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundColor(Color.backgroundPrimary)
                                .frame(width: 44, height: 44)
                                .background(Color.primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.borderless)
                        
                        // Leave Group Button
                        Button(action: {
                            HapticManager.shared.medium()
                            onLeaveGroup()
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.borderless)
                    }
                }
            )
        }
    }
}

struct DebtInstructionRow: View {
    let debtorName: String
    let creditorName: String
    let amount: Double
    var currency: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ProfileAvatar(text: String(debtorName.prefix(1)), color: .secondary, size: 32)
                Text(debtorName).font(.subheadline).fontWeight(.medium).lineLimit(1)
            }
            Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
            HStack(spacing: 8) {
                ProfileAvatar(text: String(creditorName.prefix(1)), color: .secondary, size: 32)
                Text(creditorName).font(.subheadline).fontWeight(.medium).lineLimit(1)
            }
            Spacer()
            Text("\(currency.isEmpty ? "$" : currency) \(String(format: "%.2f", amount))").font(.subheadline).fontWeight(.bold)
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
    let onDelete: () -> Void
    var onNudge: (() -> Void)? = nil
    
    /// Whether the current user is the sender (creditor) of this split request
    private var isSender: Bool { split.fromUid == userId }
    
    // Helper to determine display name
    private var displayName: String {
        if isSender {
            return split.toName ?? "Friend"   // Sender sees who they requested from
        } else {
            return split.fromName ?? "Friend" // Receiver sees who requested
        }
    }
    
    private var accentColor: Color { isSender ? .green : .orange }
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Icon
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: isSender ? "creditcard.fill" : "arrow.up.right")
                        .font(.headline)
                        .foregroundColor(accentColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // FIX 3.5: Guest indicator badge
                    if split.isGuest == true {
                        Text("Guest")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary)
                            .clipShape(Capsule())
                    }
                }
                
                let note = split.note?.isEmpty == false ? split.note! : "Expense"
                if isSender {
                    Text("You requested $\(String(format: "%.2f", split.amount)) for \(note)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("requests $\(String(format: "%.2f", split.amount)) for \(note)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Time
                Text(isSender ? "Sent \(timeAgo(from: split.createdAt))" : "Requested \(timeAgo(from: split.createdAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // FIX 3.5: Guest explanation
                if split.isGuest == true {
                    Text("Manual tracking — no account")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if isSender {
                    // Sender: Cancel + Nudge
                    Button(action: {
                        HapticManager.shared.light()
                        onDelete()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        HapticManager.shared.light()
                        onNudge?()
                    }) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Receiver: Decline + Accept
                    Button(action: {
                        HapticManager.shared.light()
                        onDelete()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Accept / Pay
                    Button(action: {
                        onToggle()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.backgroundPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.functionalIncome)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(AppSpacing.element)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(accentColor, lineWidth: 1)
        )
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct GroupTransactionRow: View {
    let transaction: FirestoreModels.GroupTransaction
    let currentUserId: String
    
    // We need appState to check for "You" logic properly, but it's not passed in.
    // Ideally, we should pass in the current user's name or use EnvironmentObject if available.
    // Since this is a subview, we can use @EnvironmentObject.
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            CategoryIconView(
                category: transaction.category,
                iconOverride: transaction.icon,
                colorOverride: transaction.colorHex,
                type: transaction.type
            )
            
            VStack(alignment: .leading, spacing: 4) {
                let displayTitle = (transaction.note?.isEmpty == false) ? transaction.note! : transaction.title
                Text(displayTitle)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                let payerName = (transaction.payerId == currentUserId) ? "You" : transaction.payerName
                HStack(spacing: 4) {
                    if transaction.type == "settlement" {
                        if let receiver = transaction.receiverName {
                            // If receiver is me, show "You"
                            // If payer is me, show "You paid X"
                            let receiverDisplay: String = {
                                if let rid = transaction.receiverId, rid == appState.currentUserId {
                                    return "You"
                                } else if receiver == appState.userName {
                                    return "You"
                                }
                                return receiver
                            }()
                            
                            Text("\(payerName) paid \(receiverDisplay)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        } else {
                            Text("\(payerName) paid settlement")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("\(payerName) paid")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", abs(transaction.amount)))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(transaction.type == "settlement" || transaction.type == "income" ? .green : .primary)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .padding(AppSpacing.element)
    }
}
