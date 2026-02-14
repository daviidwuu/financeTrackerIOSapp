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
    @State private var showingMembers = false
    @State private var showingSimplification = false
    @State private var groupBalances: [String: Double] = [:]
    
    // Feature State
    @State private var pendingSplits: [FirestoreModels.SplitRequest] = []
    @State private var selectedSplit: FirestoreModels.SplitRequest?
    @State private var selectedTransaction: FirestoreModels.GroupTransaction?
    @State private var debtInstructions: [SocialRepository.DebtInstruction] = []
    
    // Undo State
    @State private var recentlyPaidSplit: FirestoreModels.SplitRequest?
    @State private var recentlyPaidSplitIds: Set<String> = [] // Fix for sync jitter
    @State private var showUndoToast = false
    @State private var undoWorkItem: DispatchWorkItem?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: AppSpacing.section) {
                    // 1. New Custom Header
                    GroupHeaderView(
                        group: group,
                        onSettleUp: { showingSettleUp = true },
                        onSimplify: { showingSimplification = true },
                        onSettings: { showingSettings = true },
                        onMembers: { showingMembers = true }
                    )
                    
                    // 1.5 Spending Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Summary")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        HStack(spacing: AppSpacing.element) {
                            let expenses = repo.groupTransactions.filter { $0.type != "settlement" }
                            
                            SpendingCard(
                                title: "Total Spend",
                                amount: abs(expenses.reduce(0) { $0 + $1.amount }),
                                icon: "chart.bar.fill",
                                color: .blue
                            )
                            
                            SpendingCard(
                                title: "You Paid",
                                amount: abs(expenses.filter { $0.payerId == appState.currentUserId }.reduce(0) { $0 + $1.amount }),
                                icon: "person.fill",
                                color: .purple
                            )
                        }
                        .padding(.horizontal, AppSpacing.margin)
                    }
                    
                    // 2. Balances
                    VStack(alignment: .leading, spacing: AppSpacing.element) {
                        HStack {
                            Text("Balances")
                                .font(.headline)
                            Spacer()
                            // Future: "See All" button?
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        
                        if groupBalances.isEmpty {
                            Text("No active debts")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, AppSpacing.margin)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // Iterate all balances (including former members)
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
                        
                        // 2.1 Debt Resolution
                        if !debtInstructions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Settlement Plan")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
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
                    
                    // 2.5 Pending Splits
                    if !pendingSplits.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.element) {
                            HStack {
                                Text("Pending Requests")
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
                    
                    // 3. Activity Feed
                    VStack(alignment: .leading, spacing: AppSpacing.element) {
                        Text("Recent Activity")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        VStack(spacing: 16) { // More breathing room
                            if repo.isLoading && repo.groupTransactions.isEmpty {
                                ProgressView().padding()
                            } else if repo.groupTransactions.isEmpty {
                                ContentUnavailableView("No Activity", systemImage: "list.bullet.clipboard", description: Text("Transactions will appear here."))
                            } else {
                                LazyVStack(spacing: 16) { // ✅ LazyVStack for performance
                                    ForEach(repo.groupTransactions) { transaction in
                                        GroupTransactionRow(transaction: transaction, currentUserId: appState.currentUserId)
                                            .background(Color(UIColor.secondarySystemBackground))
                                            .cornerRadius(AppRadius.medium)
                                            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
                                            .onTapGesture { selectedTransaction = transaction }
                                            .contextMenu {
                                                if transaction.payerId == appState.currentUserId {
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
            .coordinateSpace(name: "scroll") // For sticky headers if needed later
            
            // Undo Toast Overlay
            if showUndoToast {
                UndoToast(text: "Marked as paid", onUndo: undoPayment)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .overlay(
            // ✅ Sticky Header Buttons
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
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, geo.safeAreaInsets.top + 8)
            }
            .ignoresSafeArea(edges: .top),
            alignment: .top
        )
        .navigationBarHidden(true) // Hide default nav bar for custom header
        .ignoresSafeArea(edges: .top)
        .onAppear { loadGroupData() }
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
        .sheet(item: $selectedTransaction, onDismiss: { loadGroupData() }) { transaction in GroupTransactionDetailView(transaction: transaction) }
        .onReceive(repo.$groupBalances) { newBalances in
             groupBalances = newBalances
             debtInstructions = repo.calculateDebtResolution(balances: newBalances)
        }
        .onReceive(repo.$myPendingGroupSplits) { newSplits in
             // Filter out splits that we know we just paid (but server might still send as pending for a split second)
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
        
        // Immediate Optimistic Update
        withAnimation { 
            pendingSplits.removeAll { $0.id == split.id } 
            if let id = split.id {
                recentlyPaidSplitIds.insert(id) // Add to ignore list
            }
        }
        
        recentlyPaidSplit = split
        withAnimation { showUndoToast = true }
        undoWorkItem?.cancel()
        
        Task {
            do {
                try await SocialTransactionManager.shared.markSplitAsPaid(request: split, currentUserId: appState.currentUserId, currentUserName: appState.userName)
                loadGroupData()
                
                // Success: Keep in ignore list for a bit longer to ensure server catch-up
                // Then remove to avoid memory leak (though set is small)
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                await MainActor.run { 
                    if let id = split.id {
                        recentlyPaidSplitIds.remove(id) 
                    }
                }
            } catch {
                print("Error: \(error)")
                await MainActor.run { 
                    // Revert on error
                    pendingSplits.append(split)
                    pendingSplits.sort { $0.createdAt > $1.createdAt }
                    if let id = split.id {
                        recentlyPaidSplitIds.remove(id)
                    }
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
            if let id = split.id {
                recentlyPaidSplitIds.remove(id) // Stop ignoring it
            }
        }
        
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
    
    private func deleteSplit(_ split: FirestoreModels.SplitRequest) {
        HapticManager.shared.heavy()
        Task {
            do {
                try await SocialTransactionManager.shared.deleteSplitRequestAndSync(request: split)
            } catch { print("Error deleting split: \(error)") }
        }
    }
    
    func getMemberName(id: String) -> String {
        if id == appState.currentUserId { return "You" }
        if let friend = appState.friendRepo.friends.first(where: { $0.id == id }) { return friend.name }
        if let guest = appState.guestRepo.guests.first(where: { $0.id == id }) { return guest.name }
        // Fallback to denormalized name
        if let name = group.memberNames?[id] { return name }
        return "Member"
    }
}

// MARK: - Subviews

struct GroupHeaderView: View {
    let group: FirestoreModels.Group
    let onSettleUp: () -> Void
    let onSimplify: () -> Void
    let onSettings: () -> Void
    let onMembers: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background with Black
            Color.black
                .frame(height: 300) // Taller header for extra button
                .overlay(Color.black.opacity(0.2))
            
            VStack(spacing: 0) {
                Spacer()
                
                // Group Info
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                        
                        Image(systemName: group.icon)
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    
                    VStack(spacing: 4) {
                        Text(group.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                        
                        Button(action: onMembers) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                Text("\(group.members.count) members")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }
                    
                    // Main Actions
                    HStack(spacing: 12) {
                        Button(action: onSettleUp) {
                            HStack {
                                Image(systemName: "banknote.fill")
                                Text("Settle Up")
                            }
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: group.color))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        
                        Button(action: onSimplify) {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
        .frame(height: 300)
        .mask(Rectangle())
    }
}

struct DebtInstructionRow: View {
    let debtorName: String
    let creditorName: String
    let amount: Double
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ProfileAvatar(text: String(debtorName.prefix(1)), color: .red.opacity(0.7), size: 32)
                Text(debtorName).font(.subheadline).fontWeight(.medium).lineLimit(1)
            }
            Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
            HStack(spacing: 8) {
                ProfileAvatar(text: String(creditorName.prefix(1)), color: .green.opacity(0.7), size: 32)
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
    
    private var isOwed: Bool {
        split.fromUid == userId
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Icon
            Circle()
                .fill(isOwed ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: isOwed ? "arrow.down.left" : "arrow.up.right") // In/Out arrows
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
                        Text("\(split.toName ?? "Friend")")
                            .fontWeight(.medium)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("You")
                            .fontWeight(.bold)
                    } else {
                        Text("You")
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(split.fromName ?? "Friend")")
                            .fontWeight(.medium)
                    }
                    
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(split.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", split.amount))")
                    .font(.headline)
                    .fontWeight(.heavy) // Prominent amount
                    .foregroundColor(isOwed ? .green : .primary) // Green if incoming
                
                Button(action: onToggle) {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.element)
        .background(Color(UIColor.secondarySystemBackground)) // Card background
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(isOwed ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1) // Color hints
        )
    }
}

struct GroupTransactionRow: View {
    let transaction: FirestoreModels.GroupTransaction
    let currentUserId: String
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: transaction.colorHex ?? "#808080").opacity(0.15))
                    .frame(width: 48, height: 48)
                
                if transaction.type == "settlement" {
                     Image(systemName: "banknote.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.functionalSuccess)
                } else {
                    Image(systemName: transaction.icon ?? "cart.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: transaction.colorHex ?? "#808080"))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                let displayTitle = (transaction.note?.isEmpty == false) ? transaction.note! : transaction.title
                
                Text(displayTitle)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                let payerName = (transaction.payerId == currentUserId) ? "You" : transaction.payerName
                
                HStack(spacing: 4) {
                    Text("\(payerName) paid")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if transaction.type == "settlement" {
                         Text("Settlement")
                             .font(.caption)
                             .fontWeight(.bold)
                             .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.currencyCode ?? "USD") // Replace with symbol logic later if needed
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .hidden() // Spacer logic
                
                
                
                Text("$\(String(format: "%.2f", abs(transaction.amount)))")
                    .font(.headline) // Much larger
                    .fontWeight(.bold)
                    .foregroundColor(transaction.type == "settlement" || transaction.type == "income" ? .green : .primary)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .padding(AppSpacing.element) // Consistent padding
    }
}

