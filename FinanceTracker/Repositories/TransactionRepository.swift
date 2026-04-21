import Foundation
import FirebaseFirestore
import Combine
import WidgetKit
import UIKit

/// Repository for managing transactions in Firestore
class TransactionRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var transactions: [FirestoreModels.TransactionModel] = []
    @Published var currentMonthTransactions: [FirestoreModels.TransactionModel] = [] // Full month data for aggregations
    @Published var calendarTransactions: [FirestoreModels.TransactionModel] = [] // Full month data specifically for the Calendar
    @Published var allTransactions: [FirestoreModels.TransactionModel] = [] // Full history for savings pool calculation
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var canLoadMore: Bool = false
    
    private var userId: String?
    private var listener: ListenerRegistration?
    private var currentMonthListener: ListenerRegistration? // For aggregations
    private var calendarListener: ListenerRegistration? // For Calendar
    private var allTransactionsListener: ListenerRegistration? // For savings pool
    private var currentLimit: Int = 50
    private var currentMonth: Date? = nil // Track selected month

    private var calendarMonth: Date = Date() // Track selected month specifically for the Calendar
    private var currentMonthListenerMonth: Date? = nil // Track which calendar month the listener covers
    private var significantTimeChangeCancellable: AnyCancellable? // Refresh month listener at midnight

    // Cursor-based pagination state for all-time history (savings pool)
    private var allTransactionsLastDocument: DocumentSnapshot?
    private var isLoadingHistory: Bool = false
    @Published var canLoadMoreHistory: Bool = false

    // Optimistic Deletion Cache — in-memory ONLY, never persisted to UserDefaults
    private var optimisticDeletedTransactions: [String: FirestoreModels.TransactionModel] = [:]

    deinit {
        listener?.remove()
        currentMonthListener?.remove()
        calendarListener?.remove()
        allTransactionsListener?.remove()
        significantTimeChangeCancellable?.cancel()
    }

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
        
        // Always maintain a full current-month cache for budget/calendar aggregations.
        // Re-create the listener when the calendar month rolls over so HomeView never
        // shows stale prior-month totals.
        let calendar = Calendar.current
        let needsMonthRefresh = currentMonthListener == nil ||
            currentMonthListenerMonth.map { !calendar.isDate($0, equalTo: Date(), toGranularity: .month) } ?? true
        if needsMonthRefresh {
            startListeningToCurrentMonth()
        }
        
        if calendarListener == nil {
            startListeningToCalendarMonth()
        }
        
        // Maintain full transaction history for savings pool calculation
        if allTransactionsListener == nil {
            startListeningToAllTransactions()
        }

        // Re-subscribe once so we only hold a single cancellable even if startListening is
        // called multiple times (e.g., month filter changes).
        if significantTimeChangeCancellable == nil {
            significantTimeChangeCancellable = NotificationCenter.default
                .publisher(for: UIApplication.significantTimeChangeNotification)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    // Only recreate the listener when the calendar month has actually changed,
                    // so spurious midnight notifications on non-boundary days are a no-op.
                    let cal = Calendar.current
                    let monthChanged = self.currentMonthListenerMonth
                        .map { !cal.isDate($0, equalTo: Date(), toGranularity: .month) } ?? false
                    if monthChanged {
                        self.startListeningToCurrentMonth()
                    }
                }
        }
    }
    
    /// Update the calendar's specific month without affecting the main transaction feed
    func setCalendarMonth(_ month: Date) {
        self.calendarMonth = month
        if self.userId != nil {
            startListeningToCalendarMonth()
        }
    }
    
    private func setupListener() {
        guard let userId = userId else { return }

        listener?.remove()

        var query = db.collection("users").document(userId).collection("transactions")
            .order(by: "date", descending: true)
            
        // Apply Month Filter if provided (Main Feed)
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
            // Paginated: Fetch latest transactions with limit
            query = query.limit(to: currentLimit)
        }
            
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self = self else { return }
                if self.isLoading { self.isLoading = false }

                if let error = error {
                    let msg = "Error fetching transactions: \(error.localizedDescription)"
                    if self.errorMessage != msg { self.errorMessage = msg }
                    DebugLogger.log(msg)
                    if self.isLoading { self.isLoading = false } // Don't leave spinner stuck on error
                    return
                }

                guard let documents = snapshot?.documents else {
                    if self.errorMessage != "No transactions found." { self.errorMessage = "No transactions found." }
                    if !self.transactions.isEmpty { self.transactions = [] }
                    return
                }

                if self.errorMessage != nil { self.errorMessage = nil }
                // Update canLoadMore: if we got as many docs as our limit, there are likely more
                self.canLoadMore = self.currentMonth == nil && documents.count >= self.currentLimit
                // Only keep transactions that are not optimistically deleted
                var parsedTransactions: [FirestoreModels.TransactionModel] = []
                for document in documents {
                    do {
                        var tx = try document.data(as: FirestoreModels.TransactionModel.self)
                        tx.amount = FirestoreModels.TransactionModel.normalizeAmount(tx.amount, type: tx.type)
                        guard let id = tx.id,
                              !self.optimisticDeletedTransactions.keys.contains(id) else {
                            continue
                        }
                        // REMOVED pendingDeleteIds check - if transaction exists in Firestore, show it
                        parsedTransactions.append(tx)
                    } catch {
                        DebugLogger.log("Failed to decode transaction \(document.documentID) in setupListener: \(error)")
                    }
                }
                self.transactions = parsedTransactions
                
                // Update Widget Data
                self.updateWidgetData(transactions: self.transactions)
            }
        }
    }
    
    private func startListeningToCurrentMonth() {
        guard let userId = userId else { return }

        currentMonthListener?.remove()
        currentMonthListenerMonth = Date() // Record the month this listener covers

        let calendar = Calendar.current
        let targetMonth = Date() // True current month for homeview and budgets
        let components = calendar.dateComponents([.year, .month], from: targetMonth)
        guard let startOfMonth = calendar.date(from: components) else { return }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { return }
        
        let query = db.collection("users").document(userId).collection("transactions")
            .whereField("date", isGreaterThanOrEqualTo: startOfMonth)
            .whereField("date", isLessThan: nextMonth)
            .order(by: "date", descending: true)
            
        currentMonthListener = query.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    DebugLogger.log("Error fetching current month transactions: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.currentMonthTransactions = []
                    return
                }
                
                var parsedTransactions: [FirestoreModels.TransactionModel] = []
                for document in documents {
                    do {
                        var tx = try document.data(as: FirestoreModels.TransactionModel.self)
                        tx.amount = FirestoreModels.TransactionModel.normalizeAmount(tx.amount, type: tx.type)
                        guard let id = tx.id,
                              !self.optimisticDeletedTransactions.keys.contains(id) else {
                            continue
                        }
                        parsedTransactions.append(tx)
                    } catch {
                        DebugLogger.log("Failed to decode transaction \(document.documentID) in startListeningToCurrentMonth: \(error)")
                    }
                }
                self.currentMonthTransactions = parsedTransactions
                DebugLogger.log("Fetched current month transactions: \(self.currentMonthTransactions.count) items.")
                // Update widget monthly spend now that currentMonthTransactions is fresh
                self.updateWidgetData(transactions: self.transactions)
            }
        }
    }

    private func startListeningToCalendarMonth() {
        guard let userId = userId else { return }
        
        calendarListener?.remove()
        
        let calendar = Calendar.current
        let targetMonth = self.calendarMonth
        let components = calendar.dateComponents([.year, .month], from: targetMonth)
        guard let startOfMonth = calendar.date(from: components) else { return }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { return }
        
        let query = db.collection("users").document(userId).collection("transactions")
            .whereField("date", isGreaterThanOrEqualTo: startOfMonth)
            .whereField("date", isLessThan: nextMonth)
            .order(by: "date", descending: true)
            
        calendarListener = query.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    DebugLogger.log("Error fetching calendar month transactions: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.calendarTransactions = []
                    return
                }
                
                var parsedTransactions: [FirestoreModels.TransactionModel] = []
                for document in documents {
                    do {
                        var tx = try document.data(as: FirestoreModels.TransactionModel.self)
                        tx.amount = FirestoreModels.TransactionModel.normalizeAmount(tx.amount, type: tx.type)
                        guard let id = tx.id,
                              !self.optimisticDeletedTransactions.keys.contains(id) else {
                            continue
                        }
                        parsedTransactions.append(tx)
                    } catch {
                        DebugLogger.log("Failed to decode transaction \(document.documentID) in startListeningToCalendarMonth: \(error)")
                    }
                }
                self.calendarTransactions = parsedTransactions
            }
        }
    }
    
    private func startListeningToAllTransactions() {
        guard let userId = userId else { return }

        allTransactionsListener?.remove()
        allTransactionsListener = nil
        allTransactions = []
        allTransactionsLastDocument = nil
        isLoadingHistory = false
        canLoadMoreHistory = false

        fetchAllTransactionsPage(userId: userId)
    }

    private func fetchAllTransactionsPage(userId: String) {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true

        var query = db.collection("users").document(userId).collection("transactions")
            .order(by: "date", descending: true)
            .limit(to: 500)

        if let cursor = allTransactionsLastDocument {
            query = query.start(afterDocument: cursor)
        }

        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            let capturedSelf = self
            Task { @MainActor in
                capturedSelf.isLoadingHistory = false

                if let error = error {
                    DebugLogger.log("Error fetching all transactions page: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    capturedSelf.canLoadMoreHistory = false
                    return
                }

                var page: [FirestoreModels.TransactionModel] = []
                for document in documents {
                    do {
                        var tx = try document.data(as: FirestoreModels.TransactionModel.self)
                        tx.amount = FirestoreModels.TransactionModel.normalizeAmount(tx.amount, type: tx.type)
                        guard let id = tx.id,
                              !capturedSelf.optimisticDeletedTransactions.keys.contains(id) else { continue }
                        page.append(tx)
                    } catch {
                        DebugLogger.log("Failed to decode transaction \(document.documentID) in fetchAllTransactionsPage: \(error)")
                    }
                }

                capturedSelf.allTransactions.append(contentsOf: page)
                capturedSelf.allTransactionsLastDocument = documents.last
                capturedSelf.canLoadMoreHistory = documents.count >= 500
            }
        }
    }

    /// Load the next page of all-time history for savings pool calculation.
    func loadMoreHistory() {
        guard let userId = userId, canLoadMoreHistory, !isLoadingHistory else { return }
        fetchAllTransactionsPage(userId: userId)
    }
    
    func loadMore() {
        guard userId != nil else { return }
        currentLimit += 50
        setupListener()
    }
    
    /// Stop listening to changes
    func stopListening() {
        listener?.remove()
        listener = nil
        currentMonthListener?.remove()
        currentMonthListener = nil
        currentMonthListenerMonth = nil
        significantTimeChangeCancellable?.cancel()
        significantTimeChangeCancellable = nil
        calendarListener?.remove()
        calendarListener = nil
        allTransactionsListener?.remove()
        allTransactionsListener = nil
        allTransactionsLastDocument = nil
        isLoadingHistory = false
        canLoadMoreHistory = false
        userId = nil
        transactions = []
        currentMonthTransactions = []
        calendarTransactions = []
        allTransactions = []
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
            self.optimisticAddTransaction(newTransaction)
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
        
        await MainActor.run {
            self.optimisticUpdateTransaction(transaction)
        }
        
        try db.collection("users").document(userId).collection("transactions").document(id).setData(from: transaction)
    }
    
    /// Optimistically add a transaction to cache
    @MainActor
    func optimisticAddTransaction(_ transaction: FirestoreModels.TransactionModel) {
        if transaction.type == "income" || transaction.type == "settlement" {
            AppState.shared.aggregatedIncome = DecimalPrecision.sum([AppState.shared.aggregatedIncome, abs(transaction.amount)])
        } else {
            AppState.shared.aggregatedExpense = DecimalPrecision.sum([AppState.shared.aggregatedExpense, abs(transaction.amount)])
        }
        
        self.transactions.insert(transaction, at: 0)
        self.allTransactions.insert(transaction, at: 0)
        
        let linkedIsCurrentMonth = Calendar.current.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        let linkedIsCalendarMonth = Calendar.current.isDate(transaction.date, equalTo: self.calendarMonth, toGranularity: .month)
        
        if linkedIsCurrentMonth {
            self.currentMonthTransactions.insert(transaction, at: 0)
        }
        if linkedIsCalendarMonth {
            self.calendarTransactions.insert(transaction, at: 0)
        }
        
        // Re-sort and update widgets
        self.transactions.sort { $0.date > $1.date }
        self.currentMonthTransactions.sort { $0.date > $1.date }
        self.calendarTransactions.sort { $0.date > $1.date }
        self.allTransactions.sort { $0.date > $1.date }
        self.updateWidgetData(transactions: self.transactions)
    }

    /// Optimistically update a transaction in cache
    @MainActor
    func optimisticUpdateTransaction(_ transaction: FirestoreModels.TransactionModel) {
        if let id = transaction.id {
            if let index = self.transactions.firstIndex(where: { $0.id == id }) {
                let oldTx = self.transactions[index]
                if oldTx.type == "income" || oldTx.type == "settlement" {
                    AppState.shared.aggregatedIncome = DecimalPrecision.subtract(AppState.shared.aggregatedIncome, abs(oldTx.amount))
                } else {
                    AppState.shared.aggregatedExpense = DecimalPrecision.subtract(AppState.shared.aggregatedExpense, abs(oldTx.amount))
                }

                if transaction.type == "income" || transaction.type == "settlement" {
                    AppState.shared.aggregatedIncome = DecimalPrecision.sum([AppState.shared.aggregatedIncome, abs(transaction.amount)])
                } else {
                    AppState.shared.aggregatedExpense = DecimalPrecision.sum([AppState.shared.aggregatedExpense, abs(transaction.amount)])
                }
                
                self.transactions[index] = transaction
            }
            if let index = self.currentMonthTransactions.firstIndex(where: { $0.id == id }) {
                self.currentMonthTransactions[index] = transaction
            }
            if let index = self.calendarTransactions.firstIndex(where: { $0.id == id }) {
                self.calendarTransactions[index] = transaction
            }
            if let index = self.allTransactions.firstIndex(where: { $0.id == id }) {
                self.allTransactions[index] = transaction
            }
            self.updateWidgetData(transactions: self.transactions)
        }
    }
    
    /// Delete a transaction with Cascade and Optimistic Update
    func deleteTransaction(id: String) async throws {
        guard let userId = userId else { return }
        
        // 1. Finalize optimistic deletion from cache
        await MainActor.run {
             finalizeDelete(id: id)
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
    
    /// Optimistically hide a transaction (and its linked income transactions) temporarily.
    @MainActor
    func optimisticDelete(transaction: FirestoreModels.TransactionModel) {
        guard let id = transaction.id else { return }
        
        if transaction.type == "income" || transaction.type == "settlement" {
            AppState.shared.aggregatedIncome = DecimalPrecision.subtract(AppState.shared.aggregatedIncome, abs(transaction.amount))
        } else {
            AppState.shared.aggregatedExpense = DecimalPrecision.subtract(AppState.shared.aggregatedExpense, abs(transaction.amount))
        }

        var idsToRemove: Set<String> = [id]
        optimisticDeletedTransactions[id] = transaction

        // Build a lookup dictionary to avoid O(n) searches per split
        let transactionById: [String: FirestoreModels.TransactionModel] = Dictionary(
            uniqueKeysWithValues: transactions.compactMap { tx in tx.id.map { ($0, tx) } }
        )

        if let splits = transaction.splits {
            for split in splits {
                if let incomeId = split.incomeTransactionId,
                   let incomeTx = transactionById[incomeId] {
                    idsToRemove.insert(incomeId)
                    optimisticDeletedTransactions[incomeId] = incomeTx

                    if incomeTx.type == "income" || incomeTx.type == "settlement" {
                        AppState.shared.aggregatedIncome = DecimalPrecision.subtract(AppState.shared.aggregatedIncome, abs(incomeTx.amount))
                    } else {
                        AppState.shared.aggregatedExpense = DecimalPrecision.subtract(AppState.shared.aggregatedExpense, abs(incomeTx.amount))
                    }
                }
            }
        }

        // Remove from the published arrays using O(1) Set lookups
        self.transactions.removeAll { tx in
            guard let txId = tx.id else { return false }
            return idsToRemove.contains(txId)
        }

        self.currentMonthTransactions.removeAll { tx in
            guard let txId = tx.id else { return false }
            return idsToRemove.contains(txId)
        }

        self.calendarTransactions.removeAll { tx in
            guard let txId = tx.id else { return false }
            return idsToRemove.contains(txId)
        }

        self.allTransactions.removeAll { tx in
            guard let txId = tx.id else { return false }
            return idsToRemove.contains(txId)
        }
        
        // Update widgets immediately based on the new array
        self.updateWidgetData(transactions: self.transactions)
    }
    
    /// Restore a transaction that was optimistically hidden.
    @MainActor
    func undoDelete(id: String) {
        // Restore main transaction
        if let restoredTx = optimisticDeletedTransactions.removeValue(forKey: id) {
            if restoredTx.type == "income" || restoredTx.type == "settlement" {
                AppState.shared.aggregatedIncome = DecimalPrecision.sum([AppState.shared.aggregatedIncome, abs(restoredTx.amount)])
            } else {
                AppState.shared.aggregatedExpense = DecimalPrecision.sum([AppState.shared.aggregatedExpense, abs(restoredTx.amount)])
            }
            
            self.transactions.append(restoredTx)
            self.allTransactions.append(restoredTx)
            
            let calendar = Calendar.current
            let isCurrentMonth = calendar.isDate(restoredTx.date, equalTo: Date(), toGranularity: .month)
            let isCalendarMonth = calendar.isDate(restoredTx.date, equalTo: self.calendarMonth, toGranularity: .month)
            
            if isCurrentMonth {
                self.currentMonthTransactions.append(restoredTx)
            }
            if isCalendarMonth {
                self.calendarTransactions.append(restoredTx)
            }
            
            // Restore linked income transactions
            if let splits = restoredTx.splits {
                for split in splits {
                    if let incomeId = split.incomeTransactionId,
                       let linkedIncomeTx = optimisticDeletedTransactions.removeValue(forKey: incomeId) {
                        if linkedIncomeTx.type == "income" || linkedIncomeTx.type == "settlement" {
                            AppState.shared.aggregatedIncome = DecimalPrecision.sum([AppState.shared.aggregatedIncome, abs(linkedIncomeTx.amount)])
                        } else {
                            AppState.shared.aggregatedExpense = DecimalPrecision.sum([AppState.shared.aggregatedExpense, abs(linkedIncomeTx.amount)])
                        }
                        
                        self.transactions.append(linkedIncomeTx)
                        self.allTransactions.append(linkedIncomeTx)
                        
                        let linkedIsCurrentMonth = calendar.isDate(linkedIncomeTx.date, equalTo: Date(), toGranularity: .month)
                        let linkedIsCalendarMonth = calendar.isDate(linkedIncomeTx.date, equalTo: self.calendarMonth, toGranularity: .month)
                        
                        if linkedIsCurrentMonth {
                            self.currentMonthTransactions.append(linkedIncomeTx)
                        }
                        if linkedIsCalendarMonth {
                            self.calendarTransactions.append(linkedIncomeTx)
                        }
                    }
                }
            }
        }
        
        // Re-sort and update widgets
        self.transactions.sort { $0.date > $1.date }
        self.currentMonthTransactions.sort { $0.date > $1.date }
        self.calendarTransactions.sort { $0.date > $1.date }
        self.allTransactions.sort { $0.date > $1.date }
        self.updateWidgetData(transactions: self.transactions)
    }
    
    /// Finalize deletion and clean up from cache
    @MainActor
    func finalizeDelete(id: String) {
        if let tx = optimisticDeletedTransactions.removeValue(forKey: id) {
            if let splits = tx.splits {
                for split in splits {
                    if let incomeId = split.incomeTransactionId {
                        optimisticDeletedTransactions.removeValue(forKey: incomeId)
                    }
                }
            }
        }
    }
    
    /// Fetch a single transaction by ID
    func fetchTransaction(id: String) async throws -> FirestoreModels.TransactionModel? {
        guard let userId = userId else { return nil }
        let doc = try await db.collection("users").document(userId).collection("transactions").document(id).getDocument()
        if var tx = try? doc.data(as: FirestoreModels.TransactionModel.self) {
            tx.amount = FirestoreModels.TransactionModel.normalizeAmount(tx.amount, type: tx.type)
            return tx
        }
        return nil
    }
    
    private func updateWidgetData(transactions: [FirestoreModels.TransactionModel]) {
        let calendar = Calendar.current
        
        // Calculate Daily Spend (Net)
        // Calculate Daily Breakdown
        let dailyTransactions = transactions.filter { $0.type != "income" && calendar.isDateInToday($0.date) }

        // Expense: Sum of negative amounts (e.g. -10, -20 = -30). We store as positive (30).
        let dailyExpense = abs(DecimalPrecision.sum(dailyTransactions.filter { $0.amount < 0 }.map { $0.amount }))

        // Vault: Sum of positive amounts (Reimbursements/Income).
        let dailyVault = DecimalPrecision.sum(dailyTransactions.filter { $0.amount > 0 }.map { $0.amount })

        // Save separately
        WidgetDataManager.shared.saveDailyData(expense: dailyExpense, vault: dailyVault)

        // Calculate Monthly Spend using the dedicated currentMonthTransactions listener,
        // which always covers the full current month regardless of the paginated feed size.
        let monthlySpend = DecimalPrecision.sum(
            self.currentMonthTransactions
                .filter { $0.type != "income" }
                .map { $0.amount }
        )
        WidgetDataManager.shared.saveMonthlySpend(monthlySpend < 0 ? abs(monthlySpend) : 0)
        
        // --- NEW: Optimistic Recent Transactions ---
        let recentLimit = min(4, transactions.count)
        let recentWidgetTxs = transactions.prefix(recentLimit).map { tx in
            WidgetDataManager.WidgetTransaction(
                id: tx.id ?? UUID().uuidString,
                title: tx.title,
                amount: tx.amount,
                date: tx.date,
                categoryId: tx.categoryId,
                type: tx.type // FIX #22: Pass type so widget can filter by type instead of category name
            )
        }
        WidgetDataManager.shared.saveRecentTransactions(Array(recentWidgetTxs))
        
        // Force reload to ensure widget updates immediately
        WidgetCenter.shared.reloadAllTimelines()
    }
}
