import SwiftUI
import FirebaseFirestore

struct GroupDetailView: View {
    let group: FirestoreModels.Group
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var repo = SocialRepository()
    
    // UI State
    @State private var showingSettleUp = false
    @State private var showingAddExpense = false
    @State private var showingSettings = false
    @State private var showingMembers = false
    @State private var showingSimplification = false
    @State private var groupBalances: [String: Double] = [:]
    
    // Feature State
    @State private var pendingSplits: [FirestoreModels.SplitRequest] = []
    @State private var selectedSplit: FirestoreModels.SplitRequest?
    @State private var selectedTransaction: FirestoreModels.GroupTransaction?
    @State private var debtInstructions: [DebtInstruction] = []
    
    // Undo State
    @State private var recentlyPaidSplit: FirestoreModels.SplitRequest?
    @State private var recentlyPaidSplitIds: Set<String> = [] 
    @State private var showUndoToast = false
    @State private var undoWorkItem: DispatchWorkItem?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: AppSpacing.section) {
                    // 1. Header
                    DetailHeaderView(
                        title: group.name,
                        onBack: { dismiss() },
                        onMenu: { showingSettings = true },
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
                            Button(action: { showingMembers = true }) {
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
                                Button(action: { showingSettleUp = true }) {
                                    HStack {
                                        Text("Settle")
                                            .foregroundColor(colorScheme == .dark ? .black : .white)
                                    }
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .frame(height: 44) // Match height of circle button
                                    .background(colorScheme == .dark ? Color.white : Color.black)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                }
                                
                                Button(action: { showingAddExpense = true }) {
                                    Image(systemName: "plus")
                                        .font(.headline)
                                        .foregroundColor(colorScheme == .dark ? .black : .white)
                                        .frame(width: 44, height: 44) // Matches DetailHeaderView back button size
                                        .background(colorScheme == .dark ? Color.white : Color.black)
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                }
                            }
                        }
                    )
                    
                    // 2. Pending Actions (High Priority)
                    if !pendingSplits.isEmpty {
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
                            .padding(.horizontal, AppSpacing.margin)
                            
                            VStack(spacing: 12) {
                                ForEach(pendingSplits) { split in
                                    PendingSplitCard(split: split, userId: appState.currentUserId, onToggle: {
                                        handleSplitToggle(split)
                                    })
                                    .onTapGesture { selectedSplit = split }
                                    .contextMenu {
                                        if split.fromUid == appState.currentUserId {
                                             Button(role: .destructive) { deleteSplit(split) } label: {
                                                 Label("Delete Request", systemImage: "trash")
                                             }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.margin)
                        }
                    }
                    
                    // 3. Group Overview & Stats (Consolidated)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overview")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        let expenses = repo.groupTransactions.filter { $0.type != "settlement" }
                        let totalSpend = abs(expenses.reduce(0) { $0 + $1.amount })
                        
                        // Calculate Personal Liability (Net Outflow)
                        // Formula: (Expenses I Paid) + (Settlements I Paid) - (Settlements I Received)
                        let myExpensesPaid = abs(expenses.filter { $0.payerId == appState.currentUserId }.reduce(0) { $0 + $1.amount })
                        
                        let settlements = repo.groupTransactions.filter { $0.type == "settlement" }
                        let settlementsPaid = abs(settlements.filter { $0.payerId == appState.currentUserId }.reduce(0) { $0 + $1.amount })
                        let settlementsReceived = abs(settlements.filter { $0.receiverName == appState.userName }.reduce(0) { $0 + $1.amount })
                        
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
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(AppRadius.medium)
                        }
                        .padding(.horizontal, AppSpacing.margin)
                    }

                    // 4. Balances (Who owes who)
                    if abs(groupBalances[appState.currentUserId] ?? 0) > 0.01 {
                        VStack(alignment: .leading, spacing: AppSpacing.element) {
                            HStack {
                                Text("Balances")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.margin)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    let memberIds = groupBalances.keys.sorted()
                                    ForEach(memberIds, id: \.self) { memberId in
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
                    }
                    
                    // 5. Activity Feed
                    VStack(alignment: .leading, spacing: AppSpacing.element) {
                        Text("Recent Activity")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        VStack(spacing: 16) {
                            if repo.isLoading && repo.groupTransactions.isEmpty {
                                ProgressView().padding()
                            } else if repo.groupTransactions.isEmpty {
                                ContentUnavailableView("No Activity", systemImage: "list.bullet.clipboard", description: Text("Transactions will appear here."))
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(repo.groupTransactions) { transaction in
                                        GroupTransactionRow(transaction: transaction, currentUserId: appState.currentUserId)
                                            .background(Color(UIColor.secondarySystemBackground))
                                            .cornerRadius(AppRadius.medium)
                                            .onTapGesture { selectedTransaction = transaction }
                                            .contextMenu {
                                                if transaction.payerId == appState.currentUserId || transaction.type == "settlement" {
                                                    Button(role: .destructive) { deleteTransaction(transaction) } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
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
                UndoToast(text: "Marked as paid", onUndo: undoPayment)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear { loadGroupData() }
        .sheet(isPresented: $showingAddExpense) {
            EditGroupTransactionWizardView(group: group, transactionToEdit: nil) { amount, note, splits in
                handleAddExpense(amount: amount, note: note, splits: splits)
            }
        }
        .sheet(isPresented: $showingSettings) { GroupCreationWizardView(groupToEdit: group) }
        .sheet(isPresented: $showingSettleUp, onDismiss: { loadGroupData() }) { SettleUpWizardView(group: group, preSelectedFriend: nil).presentationDetents([.large]) }
        .sheet(isPresented: $showingMembers) { GroupMembersView(group: group).presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showingSimplification) {
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
                                debtorName: getMemberName(id: instruction.debtorId),
                                creditorName: getMemberName(id: instruction.creditorId),
                                amount: instruction.amount
                            )
                        }
                    }
                    .padding()
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedSplit, onDismiss: { loadGroupData() }) { split in SplitRequestDetailView(request: split) }
        .sheet(item: $selectedTransaction, onDismiss: { loadGroupData() }) { transaction in 
             GroupTransactionDetailView(transaction: transaction, group: group)
                 .presentationDetents([.medium, .large])
                 .presentationDragIndicator(.visible)
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
    }
    
    // Logic Functions (Same as before)
    private func loadGroupData() {
        if let groupId = group.id {
            repo.fetchGroupTransactions(groupId: groupId)
            repo.listenToGroupBalances(groupId: groupId, currentUserId: appState.currentUserId)
        }
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
    
    private func deleteTransaction(_ transaction: FirestoreModels.GroupTransaction) {
        guard let groupId = group.id, let _ = transaction.id else { return }
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
        Task { try? await SocialTransactionManager.shared.deleteSplitRequestAndSync(request: split) }
    }
    
    func getMemberName(id: String) -> String {
        if id == appState.currentUserId { return "You" }
        if let friend = appState.friendRepo.friends.first(where: { $0.id == id }) { return friend.name }
        if let guest = appState.guestRepo.guests.first(where: { $0.id == id }) { return guest.name }
        if let name = group.memberNames?[id] { return name }
        return "Member"
    }
    
    private func handleAddExpense(amount: Double, note: String, splits: [FirestoreModels.Split]) {
        let transaction = FirestoreModels.TransactionModel(
            userId: appState.currentUserId,
            title: note.isEmpty ? "Group Expense" : note,
            subtitle: "Group: \(group.name)",
            amount: -abs(amount),
            date: Date(),
            type: "expense",
            createdAt: Date(),
            icon: "person.2.fill", // Or group icon
            colorHex: group.color,
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
                            let receiverDisplay = (receiver == appState.userName) ? "You" : receiver
                            
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
