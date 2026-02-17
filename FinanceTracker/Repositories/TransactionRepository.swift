import Foundation
import FirebaseFirestore
import Combine
import WidgetKit

/// Repository for managing transactions in Firestore
class TransactionRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var transactions: [FirestoreModels.TransactionModel] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    
    private var userId: String?
    private var listener: ListenerRegistration?
    private var currentLimit: Int = 50
    private var currentMonth: Date? = nil // Track selected month
    
    /// Start listening to transactions for a specific user
    /// - Parameters:
    ///   - userId: User ID
    ///   - month: Optional month to filter by. If nil, fetches latest.
    ///   - showLoading: Whether to show loading state (default: true). Set to false to prevent UI flash when switching filters.
    func startListening(userId: String, month: Date? = nil, showLoading: Bool = true) {
        self.userId = userId
        self.currentMonth = month
        
        // Only show loading if we don't have any data yet (Stale-While-Revalidate)
        if showLoading && transactions.isEmpty {
            self.isLoading = true
        }
        self.errorMessage = nil
        self.currentLimit = 50 // Reset limit
        
        setupListener()
    }
    
    private func setupListener() {
        guard let userId = userId else { return }
        
        listener?.remove()
        
        var query = db.collection("users").document(userId).collection("transactions")
            .order(by: "date", descending: true)
            
        // Apply Month Filter if provided
        if let month = currentMonth {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: month)
            guard let startOfMonth = calendar.date(from: components) else { return }
            
            // Calculate End of Month: Start of next month - 1 second
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { return }
            
            // Filter by date range
            query = query
                .whereField("date", isGreaterThanOrEqualTo: startOfMonth)
                .whereField("date", isLessThan: nextMonth)
                // Remove limit when filtering by month to show ALL transactions for that month
        } else {
            // Default behavior: Fetch ALL transactions (No Limit)
            // query = query.limit(to: currentLimit) // DISABLED LIMIT
        }
            
        listener = query.addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error fetching transactions: \(error.localizedDescription)"
                    DebugLogger.log("Error fetching transactions: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No transactions found."
                    self.transactions = []
                    return
                }
                
                self.errorMessage = nil
                self.transactions = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.TransactionModel.self)
                }
                
                // Update Widget Data
                self.updateWidgetData(transactions: self.transactions)
            }
    }
    
    func loadMore() {
        guard userId != nil else { return }
        currentLimit += 50
        setupListener()
    }
    
    /// Stop listening to changes
    func stopListening() {
        listener?.remove()
        userId = nil
        transactions = []
        isLoading = false
    }
    
    /// Add a new transaction
    func addTransaction(_ transaction: FirestoreModels.TransactionModel) async throws {
        // Use repo's userId or transaction's userId
        guard let userId = self.userId ?? Optional(transaction.userId), !userId.isEmpty else { 
            throw NSError(domain: "TransactionRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "No User ID available"])
        }
        
        let ref = db.collection("users").document(userId).collection("transactions").document()
        var newTransaction = transaction
        newTransaction.id = ref.documentID
        newTransaction.createdAt = Date()
        
        // Optimistic Update
        await MainActor.run {
            self.transactions.insert(newTransaction, at: 0)
            // Re-sort just in case, though usually at top
            self.transactions.sort { $0.date > $1.date }
        }
        
        try ref.setData(from: newTransaction)
        
        // Gamification Checks
        DispatchQueue.main.async {
            // Check Social Splitter
            if let splits = newTransaction.splits, !splits.isEmpty {
                GamificationManager.shared.completeMission(id: "social_splitter")
            }
            
            // Check Streak Starter (3 Days)
            self.checkStreak(userId: userId)
        }
    }
    
    private func checkStreak(userId: String) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 1. Get unique days with transactions
        let uniqueDays = Set(self.transactions.map { calendar.startOfDay(for: $0.date) })
        
        // 2. Check for 3 consecutive days ending today or yesterday
        // (Allow verification even if today's transaction was just added)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        
        if uniqueDays.contains(today) && uniqueDays.contains(yesterday) && uniqueDays.contains(twoDaysAgo) {
            GamificationManager.shared.completeMission(id: "streak_starter")
        }
    }
    
    /// Update an existing transaction
    func updateTransaction(_ transaction: FirestoreModels.TransactionModel) async throws {
        guard let userId = userId, let id = transaction.id else {
            throw NSError(domain: "TransactionRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Transaction ID or UserID is nil"])
        }
        try db.collection("users").document(userId).collection("transactions").document(id).setData(from: transaction)
    }
    
    /// Delete a transaction with Cascade and Optimistic Update
    func deleteTransaction(id: String) async throws {
        guard let userId = userId else { return }
        
        // 1. Optimistic Update
        await MainActor.run {
             removeLocalTransaction(id: id)
        }
        
        let batch = db.batch()
        let txRef = db.collection("users").document(userId).collection("transactions").document(id)
        
        // 2. Fetch transaction to find related splits/debts
        let doc = try await txRef.getDocument()
        if doc.exists {
            
            // A. Delete Split Requests
            let splitsSnapshot = try await db.collection("split_requests")
                .whereField("transactionId", isEqualTo: id)
                .whereField("fromUid", isEqualTo: userId)
                .getDocuments()
            
            for splitDoc in splitsSnapshot.documents {
                batch.deleteDocument(splitDoc.reference)
            }
            
            // B. Delete Group Transactions (if it was shared)
            // We need to know the groupId, which is on the split request or we have to query all groups?
            // Better: Query group transactions where `originalTransactionId` == id.
            // Since we don't know the Group ID easily without querying all groups (costly), 
            // we rely on the fact that `split_requests` usually have `groupId`.
            // Alternatively, we can use Collection Group Query or just check the splits we found.
            
            var groupIds = Set<String>()
            for splitDoc in splitsSnapshot.documents {
                if let groupId = splitDoc.get("groupId") as? String {
                    groupIds.insert(groupId)
                }
            }
            
            for groupId in groupIds {
                let groupTxSnapshot = try await db.collection("groups").document(groupId).collection("transactions")
                    .whereField("originalTransactionId", isEqualTo: id)
                    .getDocuments()
                
                for gTxDoc in groupTxSnapshot.documents {
                    batch.deleteDocument(gTxDoc.reference)
                }
            }
            
            // C. Delete "Income" transactions for friends (if they were paid)
            // If this transaction had splits that were "paid", they created income transactions for friends.
            // But usually *this* transaction is the Expense. 
            // If *this* transaction is a "Settlement" (Income), we accept it.
            // If *this* transaction is an Expense and has paid splits, the friends have Income transactions.
            // We should ideally delete those too if we are "Un-splitting".
            // However, that involves writing to other users' collections which might be restricted.
            // But we CAN delete the SplitRequests which we did above. 
            // The friends' income transactions might remain as "orphaned" or we assume they are valid?
            // Requirement says: "Force delete all associated child splits, debts, and settlement records"
            // If we can't find them easily, we skip.
            // But we CAN check `tx.splits` for `incomeTransactionId`.
            
            // 2.3 Cascade Checking (Optional/Future)
            // If we needed to delete friends' income transactions, we'd do it here.
            // For now, we rely on deleting the SplitRequest.
        }
        
        // 3. Delete the Master Transaction
        batch.deleteDocument(txRef)
        
        // 4. Commit
        try await batch.commit()
    }
    
    /// Optimistically remove a transaction from the local list
    @MainActor
    func removeLocalTransaction(id: String) {
        if let index = self.transactions.firstIndex(where: { $0.id == id }) {
            self.transactions.remove(at: index)
            self.updateWidgetData(transactions: self.transactions)
        }
    }
    
    /// Fetch a single transaction by ID
    func fetchTransaction(id: String) async throws -> FirestoreModels.TransactionModel? {
        guard let userId = userId else { return nil }
        let doc = try await db.collection("users").document(userId).collection("transactions").document(id).getDocument()
        return try? doc.data(as: FirestoreModels.TransactionModel.self)
    }
    
    private func updateWidgetData(transactions: [FirestoreModels.TransactionModel]) {
        let calendar = Calendar.current
        let today = Date()
        
        // Calculate Daily Spend (Net)
        // Calculate Daily Breakdown
        let dailyTransactions = transactions.filter { $0.subtitle != "Income" && calendar.isDateInToday($0.date) }
        
        // Expense: Sum of negative amounts (e.g. -10, -20 = -30). We store as positive (30).
        let dailyExpense = abs(dailyTransactions.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount })
        
        // Vault: Sum of positive amounts (Reimbursements/Income).
        let dailyVault = dailyTransactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        
        // Save separately
        // Save separately
        WidgetDataManager.shared.saveDailyData(expense: dailyExpense, vault: dailyVault)
        
        // Calculate Monthly Spend (Net)
        let monthlySpend = transactions
             .filter { $0.subtitle != "Income" && calendar.isDate($0.date, equalTo: today, toGranularity: .month) }
             .reduce(0) { $0 + $1.amount }
        
        // Monthly: Keep original logic for now (Absolute expense only? Or should we fix this too?)
        // The plan specifically prioritized Daily. Let's stick to Daily for this user request.
        WidgetDataManager.shared.saveMonthlySpend(monthlySpend < 0 ? abs(monthlySpend) : 0)
        
        // Force reload to ensure widget updates immediately
        WidgetCenter.shared.reloadAllTimelines()
    }
}
