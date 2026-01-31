import Foundation
import FirebaseFirestore
import Combine

/// Repository for managing transactions in Firestore
/// Repository for managing transactions in Firestore
class TransactionRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var transactions: [FirestoreModels.Transaction] = []
    private var userId: String?
    
    private var listener: ListenerRegistration?
    
    /// Start listening to transactions for a specific user
    func startListening(userId: String) {
        self.userId = userId
        listener = db.collection("users").document(userId).collection("transactions")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching transactions: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.transactions = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.Transaction.self)
                }
                
                // Update Widget Data
                if let transactions = self?.transactions {
                    self?.updateWidgetData(transactions: transactions)
                }
            }
    }
    
    /// Stop listening to changes
    func stopListening() {
        listener?.remove()
        userId = nil
    }
    
    /// Add a new transaction
    func addTransaction(_ transaction: FirestoreModels.Transaction) async throws {
        // Use repo's userId or transaction's userId
        guard let userId = self.userId ?? Optional(transaction.userId), !userId.isEmpty else { 
            throw NSError(domain: "TransactionRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "No User ID available"])
        }
        
        var newTransaction = transaction
        newTransaction.createdAt = Date()
        try db.collection("users").document(userId).collection("transactions").document().setData(from: newTransaction)
    }
    
    /// Update an existing transaction
    func updateTransaction(_ transaction: FirestoreModels.Transaction) async throws {
        guard let userId = userId, let id = transaction.id else {
            throw NSError(domain: "TransactionRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Transaction ID or UserID is nil"])
        }
        try db.collection("users").document(userId).collection("transactions").document(id).setData(from: transaction)
    }
    
    /// Delete a transaction
    func deleteTransaction(id: String) async throws {
        guard let userId = userId else { return }
        try await db.collection("users").document(userId).collection("transactions").document(id).delete()
    }
    
    private func updateWidgetData(transactions: [FirestoreModels.Transaction]) {
        let calendar = Calendar.current
        let today = Date()
        
        // Calculate Daily Spend (Expense only)
        let dailySpend = transactions
            .filter { $0.type == "expense" && calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.amount }
        
        // Calculate Monthly Spend (Expense only)
        let monthlySpend = transactions
             .filter { $0.type == "expense" && calendar.isDate($0.date, equalTo: today, toGranularity: .month) }
             .reduce(0) { $0 + $1.amount }
             
        WidgetDataManager.shared.saveDailySpend(dailySpend)
        WidgetDataManager.shared.saveMonthlySpend(monthlySpend)
    }
}

/// Repository for managing categories in Firestore


/// Repository for managing budgets in Firestore
class BudgetRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var budgets: [FirestoreModels.CategoryBudget] = []
    private var userId: String?
    
    private var listener: ListenerRegistration?
    
    func startListening(userId: String) {
        self.userId = userId
        // Listen to ALL budgets for this user (Permanent Budget Model)
        listener = db.collection("users").document(userId).collection("budgets")
            .order(by: "category")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching budgets: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let allBudgets = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.CategoryBudget.self)
                }
                
                // Deduplicate: Keep only the latest budget per category
                // Group by category
                let grouped = Dictionary(grouping: allBudgets, by: { $0.category })
                
                let uniqueBudgets = grouped.values.compactMap { budgets -> FirestoreModels.CategoryBudget? in
                    // Sort by createdAt descending (or monthStartDate if created same time)
                    return budgets.sorted { (b1, b2) in
                         if b1.createdAt == b2.createdAt {
                             return b1.monthStartDate > b2.monthStartDate
                         }
                         return b1.createdAt > b2.createdAt
                    }.first
                }
                
                self?.budgets = uniqueBudgets.sorted(by: { $0.category < $1.category })
                
                // Update Widget Data
                self?.updateWidgetData(budgets: uniqueBudgets)
                
                // Ensure default "Income" category exists (if not present in unique list)
                if !uniqueBudgets.contains(where: { $0.category == "Income" }) {
                    Task { [weak self] in
                         // Use a generic start date
                        await self?.createDefaultIncomeCategory(userId: userId, monthStartDate: Date())
                    }
                }
            }
    }
    
    private func createDefaultIncomeCategory(userId: String, monthStartDate: Date) async {
        let incomeBudget = FirestoreModels.CategoryBudget(
            category: "Income",
            totalAmount: 0, 
            icon: "plus.circle.fill",
            colorHex: "#34C759", // System Green
            frequency: "Monthly",
            type: "income",
            userId: userId,
            monthStartDate: monthStartDate,
            createdAt: Date()
        )
        
        do {
            try await addBudget(incomeBudget)
        } catch {
            print("Failed to create default Income category: \(error)")
        }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
    }
    
    func addBudget(_ budget: FirestoreModels.CategoryBudget) async throws {
        guard let userId = userId else { return }
        var newBudget = budget
        newBudget.createdAt = Date()
        try db.collection("users").document(userId).collection("budgets").document().setData(from: newBudget)
    }
    
    func updateBudget(_ budget: FirestoreModels.CategoryBudget) async throws {
        guard let userId = userId, let id = budget.id else { throw NSError(domain: "BudgetRepository", code: 400) }
        try db.collection("users").document(userId).collection("budgets").document(id).setData(from: budget)
    }
    
    // Delete all budgets with the same category name to prevent "zombies"
    func deleteBudget(_ budget: FirestoreModels.CategoryBudget) async throws {
        guard let userId = userId else { return }
        
        // Find all docs with this category
        let snapshot = try await db.collection("users").document(userId).collection("budgets")
            .whereField("category", isEqualTo: budget.category)
            .getDocuments()
            
        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }
    
    func calculateSpent(for category: String, transactions: [FirestoreModels.Transaction]) -> Double {
        return transactions
            .filter { $0.subtitle == category && $0.type == "expense" }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    private func updateWidgetData(budgets: [FirestoreModels.CategoryBudget]) {
        // Calculate Total Monthly Budget (excluding Income)
        let totalBudget = budgets
            .filter { $0.type == "expense" }
            .reduce(0) { sum, budget in
                var monthlyAmount = budget.totalAmount
                
                // Normalize frequency to Monthly
                switch budget.frequency {
                case "Weekly":
                    monthlyAmount = budget.totalAmount * 52.0 / 12.0
                case "Bi-Weekly":
                    monthlyAmount = budget.totalAmount * 26.0 / 12.0
                case "Yearly":
                    monthlyAmount = budget.totalAmount / 12.0
                default: // "Monthly" or others
                    monthlyAmount = budget.totalAmount
                }
                
                return sum + monthlyAmount
            }
            
        WidgetDataManager.shared.saveMonthlyBudget(totalBudget)
    }
    func checkAndCopyBudgets(userId: String) async {
        let calendar = Calendar.current
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        
        let db = Firestore.firestore()
        let collection = db.collection("users").document(userId).collection("budgets")
        
        do {
            // 1. Check if budgets exist for current month
            let currentSnapshot = try await collection
                .whereField("monthStartDate", isEqualTo: currentMonthStart)
                .limit(to: 1)
                .getDocuments()
            
            if !currentSnapshot.documents.isEmpty {
                return // Budgets already exist for this month
            }
            
            // 2. Find the most recent previous month with budgets
            let lastBudgetSnapshot = try await collection
                .order(by: "monthStartDate", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            guard let lastBudgetDoc = lastBudgetSnapshot.documents.first,
                  let lastBudget = try? lastBudgetDoc.data(as: FirestoreModels.CategoryBudget.self) else {
                return // No previous data to copy
            }
            
            let previousMonthStart = lastBudget.monthStartDate
            
            // 3. Fetch all budgets from that previous month
            let previousBudgetsSnapshot = try await collection
                .whereField("monthStartDate", isEqualTo: previousMonthStart)
                .getDocuments()
            
            let previousBudgets = previousBudgetsSnapshot.documents.compactMap {
                try? $0.data(as: FirestoreModels.CategoryBudget.self)
            }
            
            // 4. Batch copy them to current month
            let batch = db.batch()
            
            for budget in previousBudgets {
                var newBudget = budget
                newBudget.id = nil // New ID
                newBudget.monthStartDate = currentMonthStart
                newBudget.createdAt = Date()
                
                let ref = collection.document()
                try batch.setData(from: newBudget, forDocument: ref)
            }
            
            try await batch.commit()
            print("Successfully copied \(previousBudgets.count) budgets to new month")
            
        } catch {
            print("Error copying budgets: \(error)")
        }
    }
}

/// Repository for managing saving goals in Firestore
class SavingGoalRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var savingGoals: [FirestoreModels.SavingGoal] = []
    private var userId: String?
    
    private var listener: ListenerRegistration?
    
    func startListening(userId: String) {
        self.userId = userId
        listener = db.collection("users").document(userId).collection("savingGoals")
            .order(by: "sortOrder")
            .order(by: "targetDate")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching saving goals: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.savingGoals = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.SavingGoal.self)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
    }
    
    func addSavingGoal(_ goal: FirestoreModels.SavingGoal) async throws {
        guard let userId = userId else { return }
        var newGoal = goal
        // Append to end of list
        let maxOrder = savingGoals.map { $0.sortOrder ?? 0 }.max() ?? -1
        newGoal.sortOrder = maxOrder + 1
        newGoal.createdAt = Date()
        try db.collection("users").document(userId).collection("savingGoals").document().setData(from: newGoal)
    }
    
    func updateSavingGoal(_ goal: FirestoreModels.SavingGoal) async throws {
        guard let userId = userId, let id = goal.id else { throw NSError(domain: "SavingGoalRepository", code: 400) }
        try db.collection("users").document(userId).collection("savingGoals").document(id).setData(from: goal)
    }
    
    func reorderSavingGoals(_ goals: [FirestoreModels.SavingGoal]) {
        guard let userId = userId else { return }
        
        // Optimistic update
        self.savingGoals = goals
        
        let batch = db.batch()
        for (index, goal) in goals.enumerated() {
            guard let id = goal.id else { continue }
            let ref = db.collection("users").document(userId).collection("savingGoals").document(id)
            batch.updateData(["sortOrder": index], forDocument: ref)
        }
        
        batch.commit { error in
            if let error = error {
                print("Error reordering goals: \(error)")
            }
        }
    }
    
    /// Distributes savings amount to goals in order (Waterfall)
    func distributeSavings(amount: Double) async throws {
        guard userId != nil else { return }
        
        var remainingAmount = amount
        // Use current local order which should be correct
        let sortedGoals = savingGoals.sorted {
            ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max)
        }
        
        for goal in sortedGoals {
            if remainingAmount <= 0.01 { break } // Float precision check
            
            let needed = goal.targetAmount - goal.currentAmount
            if needed <= 0 { continue }
            
            let allocation = min(remainingAmount, needed)
            var updatedGoal = goal
            updatedGoal.currentAmount += allocation
            
            // This awaits effectively sequentially, ensuring consistency
            try await updateSavingGoal(updatedGoal)
            remainingAmount -= allocation
        }
    }
    
    func deleteSavingGoal(id: String) async throws {
        guard let userId = userId else { return }
        try await db.collection("users").document(userId).collection("savingGoals").document(id).delete()
    }
}

/// Repository for managing recurring transactions in Firestore
class RecurringTransactionRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var recurringTransactions: [FirestoreModels.RecurringTransaction] = []
    private var userId: String?
    
    private var listener: ListenerRegistration?
    
    func startListening(userId: String) {
        self.userId = userId
        listener = db.collection("users").document(userId).collection("recurringTransactions")
            .order(by: "startDate")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching recurring transactions: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.recurringTransactions = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.RecurringTransaction.self)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
    }
    
    func addRecurringTransaction(_ transaction: FirestoreModels.RecurringTransaction) async throws {
        guard let userId = userId else { return }
        var newTransaction = transaction
        newTransaction.createdAt = Date()
        try db.collection("users").document(userId).collection("recurringTransactions").document().setData(from: newTransaction)
    }
    
    func updateRecurringTransaction(_ transaction: FirestoreModels.RecurringTransaction) async throws {
        guard let userId = userId, let id = transaction.id else { throw NSError(domain: "RecurringTransactionRepository", code: 400) }
        try db.collection("users").document(userId).collection("recurringTransactions").document(id).setData(from: transaction)
    }
    
    func deleteRecurringTransaction(id: String) async throws {
        guard let userId = userId else { return }
        try await db.collection("users").document(userId).collection("recurringTransactions").document(id).delete()
    }
    
    // Check and process any due recurring transactions
    func processDueTransactions(userId: String) async {
        let db = Firestore.firestore()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        do {
            // Fetch all recurring transactions for this user
            let snapshot = try await db.collection("users").document(userId).collection("recurringTransactions").getDocuments()
            let recurringItems = snapshot.documents.compactMap { try? $0.data(as: FirestoreModels.RecurringTransaction.self) }
            
            for item in recurringItems {
                guard let itemId = item.id else { continue }
                
                // Determine the next due date
                // If never processed, use startDate. If processed, calculate next from lastProcessed.
                var nextDueDate: Date
                
                if let lastProcessed = item.lastProcessedDate {
                    // Calculate next based on frequency
                    switch item.frequency {
                    case "Daily":
                        nextDueDate = calendar.date(byAdding: .day, value: 1, to: lastProcessed)!
                    case "Weekly":
                        nextDueDate = calendar.date(byAdding: .day, value: 7, to: lastProcessed)!
                    case "Bi-Weekly":
                        nextDueDate = calendar.date(byAdding: .day, value: 14, to: lastProcessed)!
                    case "Yearly":
                        nextDueDate = calendar.date(byAdding: .year, value: 1, to: lastProcessed)!
                    default: // "Monthly"
                        nextDueDate = calendar.date(byAdding: .month, value: 1, to: lastProcessed)!
                    }
                } else {
                    // First time: use startDate
                    nextDueDate = calendar.startOfDay(for: item.startDate)
                }
                
                // Check if it's due (nextDueDate <= today)
                // Use startOfDay to ignore time components
                if calendar.startOfDay(for: nextDueDate) <= today {
                    print("Processing recurring transaction: \(item.name) due on \(nextDueDate)")
                    
                    // Force time to 00:00:00
                    let transactionDate = calendar.startOfDay(for: nextDueDate)
                    
                    // 1. Create the Transaction
                    let newTransaction = FirestoreModels.Transaction(
                        title: item.name,
                        subtitle: item.name, // Or category if we had it
                        amount: item.type == "income" ? item.amount : -abs(item.amount),
                        date: transactionDate, // FORCE 00:00
                        icon: item.icon,
                        colorHex: item.colorHex,
                        note: "Recurring: \(item.frequency)" + (item.note.map { " - \($0)" } ?? ""),
                        type: item.type ?? "expense",
                        source: "recurring", // Mark as recurring for filtering
                        userId: userId,
                        createdAt: Date()
                    )
                    
                    // 2. Update the RecurringTransaction
                    var updatedItem = item
                    updatedItem.lastProcessedDate = transactionDate // Track strictly by date
                    
                    // Batch write for atomicity
                    let batch = db.batch()
                    
                    let transactionRef = db.collection("users").document(userId).collection("transactions").document()
                    try batch.setData(from: newTransaction, forDocument: transactionRef)
                    
                    let recurringRef = db.collection("users").document(userId).collection("recurringTransactions").document(itemId)
                    try batch.setData(from: updatedItem, forDocument: recurringRef)
                    
                    try await batch.commit()
                    
                    // Send Notification
                    NotificationManager.shared.sendTransactionNotification(
                        amount: newTransaction.amount,
                        category: newTransaction.title,
                        type: newTransaction.type
                    )
                }
            }
        } catch {
            print("Error processing recurring transactions: \(error)")
        }
    }
}
