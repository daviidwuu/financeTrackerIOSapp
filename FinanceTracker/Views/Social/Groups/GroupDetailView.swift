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
    @State private var groupBalances: [String: Double] = [:]
    
    // Feature State
    @State private var pendingSplits: [FirestoreModels.SplitRequest] = []
    @State private var debtInstructions: [DebtInstruction] = []
    
    // Undo State
    @State private var recentlyPaidSplit: FirestoreModels.SplitRequest?
    @State private var recentlyPaidSplitIds: Set<String> = [] 
    @State private var showUndoToast = false
    @State private var undoWorkItem: DispatchWorkItem?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
            
            if let group = group {
                List {
                    // 1. Header
                    Section {
                        DetailHeaderView(
                            title: group.name,
                            onBack: { dismiss() },
                            onMenu: { activeSheet = .settings },
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
                                Button(action: { activeSheet = .members }) {
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
                                    .buttonStyle(.borderless)
                                    
                                    Button(action: {
                                        HapticManager.shared.light()
                                        activeSheet = .addExpense
                                    }) {
                                        Image(systemName: "plus")
                                            .font(.headline)
                                            .foregroundColor(colorScheme == .dark ? .black : .white)
                                            .frame(width: 44, height: 44) // Matches DetailHeaderView back button size
                                            .background(colorScheme == .dark ? Color.white : Color.black)
                                            .clipShape(Circle())
                                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    
                    // 2. Pending Actions (High Priority)
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
                                        PendingSplitCard(split: split, userId: appState.currentUserId, onToggle: {
                                            handleSplitToggle(split)
                                        })
                                        .onTapGesture { activeSheet = .splitDetail(split) }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            if split.fromUid == appState.currentUserId {
                                                 Button(role: .destructive) { deleteSplit(split) } label: {
                                                     Label("Delete", systemImage: "trash")
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

                    // 4. Balances (Who owes who)
                    if abs(groupBalances[appState.currentUserId] ?? 0) > 0.01 {
                        Section {
                            VStack(alignment: .leading, spacing: AppSpacing.element) {
                                HStack {
                                    Text("Balances")
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        let memberIds = groupBalances.keys.sorted()
                                        ForEach(memberIds, id: \.self) { memberId in
                                            if let bal = groupBalances[memberId], abs(bal) > 0.01 {
                                                BalanceCard(
                                                    name: getMemberName(id: memberId, group: group),
                                                    amount: abs(bal),
                                                    isOwed: bal > 0,
                                                    isSelf: memberId == appState.currentUserId
                                                )
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
                                        if transaction.payerId == appState.currentUserId || transaction.type == "settlement" {
                                            Button(role: .destructive) { deleteTransaction(transaction, group: group) } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
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
        .onAppear { loadGroupData() }
        .sheet(item: $activeSheet) { sheet in
             // Using a ZStack to ensure context is available and stable
             ZStack {
                 if let group = group {
                     switch sheet {
                     case .addExpense:
                         EditGroupTransactionWizardView(group: group, preSelectedFriend: nil, transactionToEdit: nil) { amount, note, category, splits in
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
                                             amount: instruction.amount
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
        .onChange(of: activeSheet) { _, newValue in
             // Reload data only when sheet is dismissed (becomes nil)
             if newValue == nil {
                 loadGroupData()
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
        guard let groupId = group.id, let _ = transaction.id else {
            HapticManager.shared.error()
            return
        }
        HapticManager.shared.light()
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
            }
        }
    }
    
    private func deleteSplit(_ split: FirestoreModels.SplitRequest) {
        HapticManager.shared.heavy()
        Task {
            do {
                try await SocialTransactionManager.shared.deleteSplitRequestAndSync(request: split)
            } catch {
                await MainActor.run { HapticManager.shared.error() }
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
}

// MARK: - Subviews

struct DebtInstructionRow: View {
    let debtorName: String
    let creditorName: String
    let amount: Double
    
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
            Text("$\(String(format: "%.2f", amount))").font(.subheadline).fontWeight(.bold)
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
                .accessibilityLabel("Mark as paid")
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
