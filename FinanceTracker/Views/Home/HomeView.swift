import SwiftUI
import FirebaseFirestore

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    var monthlyIncome: Double {
        WalletLogic.calculateMonthlyIncome(recurringTransactions: recurringRepo.recurringTransactions)
    }
    
    // Repositories moved to AppState
    @EnvironmentObject var transactionRepo: TransactionRepository
    @EnvironmentObject var budgetRepo: BudgetRepository
    @EnvironmentObject var recurringRepo: RecurringTransactionRepository
    @EnvironmentObject var requestRepo: RequestRepository
    @EnvironmentObject var friendRequestRepo: FriendRequestRepository
    
    @State private var showAddTransaction = false
    // showProfile moved to AppState
    @State private var showAllTransactions = false
    @State private var selectedTransaction: FirestoreModels.TransactionModel?
    @State private var transactionToEdit: FirestoreModels.TransactionModel?
    @State private var requestToAccept: FirestoreModels.SplitRequest?
    @State private var showRemainingBudget = false
    @State private var isAnimating = false
    @State private var showMissions = false
    @ObservedObject private var gamificationManager = GamificationManager.shared
    @State private var errorState = ErrorState()
    @State private var undoState = UndoState()
    @State private var groupForDeletionAction: FirestoreModels.Group? // ✅ NEW
    @State private var pendingDeletedGroupIds: Set<String> = []
    
    var totalBudget: Double {
        WalletLogic.calculateTotalBudget(budgets: budgetRepo.budgets)
    }
    
    var totalSpent: Double {
        return WalletLogic.calculateNetSpent(transactions: transactionRepo.transactions)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    // Section 1: Header & Balance
                    Section {
                        VStack(spacing: 24) {
                            // Custom Header
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Welcome")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 8) {
                                        Text(appState.userName.isEmpty ? "User" : appState.userName)
                                            .font(AppTypography.titleDisplay)
                                            .foregroundColor(.primary)
                                        
                                        // Streak Counter
                                        HStack(spacing: 4) {
                                            Image(systemName: "flame.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.orange)
                                                .scaleEffect(isAnimating ? 1.2 : 1.0)
                                                .animation(
                                                    Animation.easeInOut(duration: 1.0)
                                                        .repeatForever(autoreverses: true),
                                                    value: isAnimating
                                                )
                                            
                                            Text("\(appState.streakCount)")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.orange.opacity(0.15))
                                        )
                                        .onAppear {
                                            isAnimating = true
                                        }
                                    }
                                    if appState.isPremiumUser {
                                        PremiumBadge(size: .small)
                                            .padding(.top, 2)
                                    }
                                }
                                
                                Spacer()
                                
                                // [NEW] Mission Button
                                Button(action: { 
                                    HapticManager.shared.light()
                                    showMissions = true 
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.primary.opacity(0.05))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: "trophy.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.primary)
                                        
                                        CircularProgressView(
                                            progress: GamificationManager.shared.progressForPhase(GamificationManager.shared.currentPhase),
                                            color: .primary
                                        )
                                            .frame(width: 44, height: 44)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                
                                Button(action: { 
                                    HapticManager.shared.light()
                                    appState.showProfile = true 
                                }) {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.primary)
                                        )
                                }
                                .buttonStyle(.plain)
                                
                            }
                            .padding(.top, 10)
                            
                            // Balance Card
                            VStack(alignment: .leading, spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Balance")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("$\(String(format: "%.2f", showRemainingBudget ? (totalBudget - totalSpent) : totalSpent))")
                                            .font(AppTypography.prominentBalance)
                                            .foregroundColor(.primary)
                                            .contentTransition(.numericText())
                                        
                                        Text(showRemainingBudget ? "left" : "spent")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .transition(.opacity)
                                    }
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            showRemainingBudget.toggle()
                                        }
                                    }
                                }
                                
                                // Custom Pill-Shaped Progress Bar
                                GeometryReader { geometry in
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(height: 24)
                                        .overlay(
                                            Capsule()
                                                .fill(Color.primary)
                                                .frame(width: min(geometry.size.width * (totalSpent / max(totalBudget, 0.01)), geometry.size.width))
                                        , alignment: .leading)
                                        .clipShape(Capsule())
                                }
                                .frame(height: 24)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                            .padding(24)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
                        }

                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.bottom, AppSpacing.compact)
                    }
                    
                    // Section 1.4: Friend Requests
                    if !friendRequestRepo.incomingRequests.isEmpty {
                        Section(header: Text("Friend Requests").font(.headline)) {
                            ForEach(friendRequestRepo.incomingRequests) { request in
                                FriendRequestCard(request: request)
                                    .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .padding(.bottom, AppSpacing.compact)
                            }
                        }
                        .animation(.spring(), value: friendRequestRepo.incomingRequests.count)
                    }
                    
                    // Section 1.5: Pending Group Deletions (High Priority)
                    let pendingDeletionGroups = appState.groupRepo.groups.filter { 
                        $0.deletionStatus == "requested" && 
                        $0.memberActions?[appState.currentUserId] == "pending" &&
                        !pendingDeletedGroupIds.contains($0.id ?? "")
                    }
                    if !pendingDeletionGroups.isEmpty {
                        Section(header: Text("Action Required").font(.headline).foregroundColor(.red)) {
                            ForEach(pendingDeletionGroups) { group in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.functionalExpense.opacity(0.1))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.name)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text("Group deletion requested")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(AppSpacing.element)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(AppRadius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.functionalExpense.opacity(0.5), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    groupForDeletionAction = group
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.bottom, AppSpacing.compact)
                            }
                        }
                        .animation(.spring(), value: pendingDeletionGroups.count)
                    }

                    // Section 1.6: Pending Requests
                    let pendingRequests = requestRepo.requests.filter { $0.status == .pending }
                    if !pendingRequests.isEmpty {
                        Section(header: Text("Pending Requests").font(.headline)) {
                            ForEach(pendingRequests) { request in
                                RequestCardView(
                                    request: request,
                                    onAccept: {
                                        if request.isSettlement == true {
                                            acceptSettlement(request)
                                        } else {
                                            requestToAccept = request
                                        }
                                    },
                                    onDecline: {
                                        if request.isSettlement == true {
                                            declineSettlement(request)
                                        } else {
                                            declineRequest(request)
                                        }
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.bottom, AppSpacing.compact)
                            }
                        }
                        .animation(.spring(), value: pendingRequests.count)
                    }
                    
                    // Section 2: Recent Transactions
                    Section(header: 
                        HStack {
                            Text("Recent Transactions")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                HapticManager.shared.light()
                                showAllTransactions = true
                            }) {
                                HStack(spacing: 4) {
                                    Text("View All")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        .textCase(nil)
                    ) {
                        if transactionRepo.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 20)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else if transactionRepo.transactions.isEmpty {
                            EmptyStateView(
                                icon: "tray.fill",
                                title: "No Transactions",
                                message: "Your recent spending will show up here.",
                                actionTitle: "Add One",
                                action: { showAddTransaction = true }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            // Filter hidden transactions (Undo logic) is now handled globally in TransactionRepository
                            
                            NativeAdView()
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.bottom, AppSpacing.compact)
                                
                            ForEach(transactionRepo.transactions.prefix(appState.isPremiumUser ? 5 : 4)) { transaction in
                                TransactionRow(transaction: transaction)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .cornerRadius(AppRadius.medium)
                                    .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .padding(.bottom, AppSpacing.compact)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            HapticManager.shared.heavy()
                                            deleteTransaction(transaction)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        if !transaction.isReimbursementIncome {
                                            Button {
                                                HapticManager.shared.medium()
                                                transactionToEdit = transaction
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                    }
                                    .onTapGesture {
                                        HapticManager.shared.light()
                                        selectedTransaction = transaction
                                    }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                // FAB removed, shifted to ContentView
                
                .sheet(item: $selectedTransaction) { transaction in
                    TransactionDetailView(transaction: transaction) { original, updated in
                        updateTransaction(original, with: updated)
                    }
                    .environmentObject(appState)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
                .sheet(item: $transactionToEdit) { transaction in
                    AddTransactionView(transactionToEdit: transaction, onSave: { updatedTransaction in
                        updateTransaction(transaction, with: updatedTransaction)
                    })
                }
                .sheet(isPresented: $appState.showProfile) {
                    ProfileView()
                        .presentationBackground(Color.backgroundPrimary)
                }
                .sheet(isPresented: $showAllTransactions) {
                    AllTransactionsView(
                        transactionRepo: transactionRepo,
                        budgetRepo: budgetRepo
                    )
                    .environmentObject(appState)
                    .presentationBackground(Color.backgroundPrimary)
                }

                .sheet(isPresented: $showAddTransaction) {
                    AddTransactionView(onSave: { transaction in
                        addTransaction(transaction)
                    })
                }
                .sheet(item: $requestToAccept) { request in
                    AddTransactionView(requestToAccept: request, onSave: { transaction in
                         acceptRequest(request, transaction: transaction)
                    })
                }
                .sheet(isPresented: $showMissions) {
                    MissionHubView()
                        .environmentObject(appState)
                }
                .alert("Group Deleted: Action Required", isPresented: Binding(
                    get: { groupForDeletionAction != nil },
                    set: { _ in groupForDeletionAction = nil }
                )) {
                    Button("Keep Transaction History") {
                        if let group = groupForDeletionAction {
                            if let id = group.id {
                                pendingDeletedGroupIds.insert(id)
                            }
                            // Using the group repo from app state
                            Task {
                                do {
                                    try await appState.groupRepo.submitDeletionAction(group: group, action: "keep")
                                } catch {
                                    // Handle errors silently for optimistic UI
                                }
                            }
                        }
                    }
                    Button("Delete All History", role: .destructive) {
                        if let group = groupForDeletionAction {
                            if let id = group.id {
                                pendingDeletedGroupIds.insert(id)
                            }
                            Task {
                                do {
                                    try await appState.groupRepo.submitDeletionAction(group: group, action: "delete")
                                } catch {
                                    // Handle errors
                                }
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    if let group = groupForDeletionAction {
                        Text("\(group.name) has been deleted by the creator. What would you like to do with your transaction history?")
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Load Gamification Data - Repos are handled in AppState
                if !appState.currentUserId.isEmpty {
                    gamificationManager.loadUserData(userId: appState.currentUserId)
                }
            }
            .onChange(of: appState.currentUserId) { _, newUserId in
                if !newUserId.isEmpty {
                    gamificationManager.loadUserData(userId: newUserId)
                }
            }
        }
        .errorBanner(errorState)
        .undoableBanner(undoState)
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
                try await transactionRepo.addTransaction(firestoreTransaction)
                
                // Send notification after successful save
                NotificationManager.shared.sendTransactionNotification(
                    amount: amount,
                    category: transaction.title,
                    type: transaction.type,
                    originalAmount: transaction.originalAmount,
                    currencyCode: transaction.currencyCode
                )
            } catch {
                DebugLogger.log("Failed to add transaction: \(error)")
                errorState.show("Failed to save transaction")
            }
        }
    }
    
    private func updateTransaction(_ entity: FirestoreModels.TransactionModel, with transaction: TransactionFormData) {
        Task {
            do {
                let amount = CurrencyInput.parseOrZero(transaction.amount)
                var updatedTransaction = entity
                updatedTransaction.title = transaction.title
                updatedTransaction.subtitle = transaction.subtitle
                updatedTransaction.amount = amount
                updatedTransaction.date = transaction.date
                updatedTransaction.icon = transaction.icon
                updatedTransaction.colorHex = transaction.color.toHex() ?? "#000000"
                updatedTransaction.note = transaction.notes
                updatedTransaction.type = amount < 0 ? "expense" : "income"
                
                try await transactionRepo.updateTransaction(updatedTransaction)
                
                // Sync Social Data if splits exist
                if let splits = updatedTransaction.splits, !splits.isEmpty {
                    // Derive groupId from existing SplitRequest (if any)
                    var groupId: String? = nil
                    if let firstRequestId = splits.compactMap({ $0.requestId }).first {
                        let reqDoc = try? await Firestore.firestore().collection("split_requests").document(firstRequestId).getDocument()
                        groupId = reqDoc?.get("groupId") as? String
                    }
                    
                    try await SocialTransactionManager.shared.createSocialTransaction(
                        transaction: updatedTransaction,
                        payerUid: appState.currentUserId,
                        payerName: appState.userName,
                        groupId: groupId,
                        friendCache: appState.friendRepo.friends,
                        groupCache: appState.groupRepo.groups
                    )
                }
            } catch {
                DebugLogger.log("Failed to update transaction: \(error)")
                errorState.show("Failed to update transaction")
            }
        }
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.TransactionModel) {
        guard let id = transaction.id else { return }
        
        // Optimistic Removal globally via repository
        transactionRepo.optimisticDelete(transaction: transaction)
        
        HapticManager.shared.heavy()
        
        undoState.schedule(
            label: "Transaction deleted",
            onUndo: { [self] in
                transactionRepo.undoDelete(id: id)
            },
            onConfirm: { [self] in
                Task {
                    do {
                        // 1. Cleanup Linked Splits (Revert payments if needed)
                        let _ = await SocialTransactionManager.shared.revertLinkedSplitIfNeeded(transaction: transaction, currentUserId: appState.currentUserId)
                        
                        // 2. Delete Transaction
                        if let splits = transaction.splits, !splits.isEmpty {
                            // Social Delete (optimistic removal handled by repo, calling finalize is not strictly needed if we just call delete, but deleteTransaction handles finalize)
                            try await SocialTransactionManager.shared.deleteSocialTransaction(transaction: transaction)
                        } else {
                            // Personal Delete (Repo handles optimistic update/finalize)
                            try await transactionRepo.deleteTransaction(id: id)
                        }
                    } catch {
                        DebugLogger.log("Failed to delete transaction: \(error)")
                        errorState.show("Failed to delete transaction")
                        transactionRepo.undoDelete(id: id) // Restore on error
                    }
                }
            }
        )
    }

    // MARK: - Request Logic
    
    private func acceptSettlement(_ request: FirestoreModels.SplitRequest) {
        HapticManager.shared.success()
        Task {
            do {
                try await SocialTransactionManager.shared.acceptSettlement(request: request, currentUserId: appState.currentUserId, currentUserName: appState.userName)
            } catch {
                await MainActor.run { HapticManager.shared.error() }
            }
        }
    }
    
    private func declineSettlement(_ request: FirestoreModels.SplitRequest) {
        HapticManager.shared.heavy()
        Task {
            do {
                try await SocialTransactionManager.shared.declineSettlement(request: request)
            } catch {
                await MainActor.run { HapticManager.shared.error() }
            }
        }
    }
    
    private func acceptRequest(_ request: FirestoreModels.SplitRequest, transaction: TransactionFormData) {
        // 1. Add the transaction
        addTransaction(transaction)
        
        // 2. Update Request Status
        Task {
            do {
                guard let id = request.id else { return }
                try await requestRepo.updateRequestStatus(userId: appState.currentUserId, requestId: id, status: .accepted, lastUpdatedBy: appState.currentUserId)
            } catch {
                DebugLogger.log("Failed to accept request: \(error)")
                errorState.show("Failed to accept request")
            }
        }
    }
    
    private func declineRequest(_ request: FirestoreModels.SplitRequest) {
        Task {
            do {
                guard let id = request.id else { return }
                try await requestRepo.updateRequestStatus(userId: appState.currentUserId, requestId: id, status: .declined, lastUpdatedBy: appState.currentUserId)
                // Optionally remove from list after delay or just let status update hide it
            } catch {
                DebugLogger.log("Failed to decline request: \(error)")
                errorState.show("Failed to decline request")
            }
        }
    }
}




#Preview {
    HomeView()
        .environmentObject(AppState.shared)
}
