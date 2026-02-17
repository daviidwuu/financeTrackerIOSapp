import SwiftUI
import FirebaseFirestore

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    var monthlyIncome: Double {
        WalletLogic.calculateMonthlyIncome(recurringTransactions: recurringRepo.recurringTransactions)
    }
    
    // Repositories moved to AppState
    var transactionRepo: TransactionRepository { appState.transactionRepo }
    var budgetRepo: BudgetRepository { appState.budgetRepo }
    var recurringRepo: RecurringTransactionRepository { appState.recurringRepo }
    var requestRepo: RequestRepository { appState.requestRepo }
    var friendRequestRepo: FriendRequestRepository { appState.friendRequestRepo }
    
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
    @State private var hiddenTransactionIds: Set<String> = []
    
    var totalBudget: Double {
        WalletLogic.calculateTotalBudget(budgets: budgetRepo.budgets)
    }
    
    var totalSpent: Double {
        WalletLogic.calculateNetSpent(transactions: transactionRepo.transactions)
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
                                                .fill(Color.white)
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
                    }
                    
                    // Section 1.5: Pending Requests
                    let pendingRequests = requestRepo.requests.filter { $0.status == .pending }
                    if !pendingRequests.isEmpty {
                        Section(header: Text("Pending Requests").font(.headline)) {
                            ForEach(pendingRequests) { request in
                                RequestCardView(
                                    request: request,
                                    onAccept: {
                                        requestToAccept = request
                                    },
                                    onDecline: {
                                        declineRequest(request)
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.bottom, AppSpacing.compact)
                            }
                        }
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
                                Text("View All")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
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
                            // Filter hidden transactions (Undo logic)
                            let visibleTransactions = transactionRepo.transactions.filter { transaction in
                                guard let id = transaction.id else { return true }
                                return !hiddenTransactionIds.contains(id)
                            }
                            
                            ForEach(visibleTransactions.prefix(5)) { transaction in
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
                                        Button {
                                            HapticManager.shared.medium()
                                            transactionToEdit = transaction
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
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
        hiddenTransactionIds.insert(id)
        
        // Optimistic Removal: Immediately hide linked income transactions (if any)
        if let splits = transaction.splits {
            for split in splits {
                if let incomeId = split.incomeTransactionId {
                    hiddenTransactionIds.insert(incomeId)
                }
            }
        }
        
        HapticManager.shared.heavy()
        
        undoState.schedule(
            label: "Transaction deleted",
            onUndo: { [self] in
                hiddenTransactionIds.remove(id)
                // Restore linked income transactions
                if let splits = transaction.splits {
                    for split in splits {
                        if let incomeId = split.incomeTransactionId {
                            hiddenTransactionIds.remove(incomeId)
                        }
                    }
                }
            },
            onConfirm: { [self] in
                Task {
                    do {
                        // 1. Cleanup Linked Splits (Revert payments if needed)
                        let _ = await SocialTransactionManager.shared.revertLinkedSplitIfNeeded(transaction: transaction, currentUserId: appState.currentUserId)
                        
                        // 2. Delete Transaction
                        if let splits = transaction.splits, !splits.isEmpty {
                            // Social Delete
                            // Optimistic Update: Remove locally first
                            transactionRepo.removeLocalTransaction(id: id)
                            try await SocialTransactionManager.shared.deleteSocialTransaction(transaction: transaction)
                        } else {
                            // Personal Delete (Repo handles optimistic update)
                            try await transactionRepo.deleteTransaction(id: id)
                        }
                        
                        // 3. Cleanup Hidden ID (Item is now gone from source)
                        hiddenTransactionIds.remove(id)
                        // Also cleanup hidden IDs for linked income transactions
                        if let splits = transaction.splits {
                            for split in splits {
                                if let incomeId = split.incomeTransactionId {
                                    hiddenTransactionIds.remove(incomeId)
                                }
                            }
                        }
                    } catch {
                        DebugLogger.log("Failed to delete transaction: \(error)")
                        errorState.show("Failed to delete transaction")
                        hiddenTransactionIds.remove(id) // Restore on error
                        // Restore linked income transactions on error
                        if let splits = transaction.splits {
                            for split in splits {
                                if let incomeId = split.incomeTransactionId {
                                    hiddenTransactionIds.remove(incomeId)
                                }
                            }
                        }
                    }
                }
            }
        )
    }

    
    // MARK: - Request Logic
    
    private func acceptRequest(_ request: FirestoreModels.SplitRequest, transaction: TransactionFormData) {
        // 1. Add the transaction
        addTransaction(transaction)
        
        // 2. Update Request Status
        Task {
            do {
                guard let id = request.id else { return }
                try await requestRepo.updateRequestStatus(userId: appState.currentUserId, requestId: id, status: .accepted)
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
                try await requestRepo.updateRequestStatus(userId: appState.currentUserId, requestId: id, status: .declined)
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
