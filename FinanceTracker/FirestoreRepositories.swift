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
}

/// Repository for managing categories in Firestore
class CategoryRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var categories: [FirestoreModels.Category] = []
    private var userId: String?
    
    private var listener: ListenerRegistration?
    
    func startListening(userId: String) {
        self.userId = userId
        listener = db.collection("users").document(userId).collection("categories")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching categories: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.categories = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.Category.self)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
    }
    
    func addCategory(_ category: FirestoreModels.Category) async throws {
        guard let userId = userId else { return }
        var newCategory = category
        newCategory.createdAt = Date()
        try db.collection("users").document(userId).collection("categories").document().setData(from: newCategory)
    }
    
    func updateCategory(_ category: FirestoreModels.Category) async throws {
        guard let userId = userId, let id = category.id else { throw NSError(domain: "CategoryRepository", code: 400) }
        try db.collection("users").document(userId).collection("categories").document(id).setData(from: category)
    }
    
    func deleteCategory(id: String) async throws {
        guard let userId = userId else { return }
        try await db.collection("users").document(userId).collection("categories").document(id).delete()
    }
}

/// Repository for managing budgets in Firestore
class BudgetRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var budgets: [FirestoreModels.CategoryBudget] = []
    private var userId: String?
    
    private var listener: ListenerRegistration?
    
    func startListening(userId: String, monthStartDate: Date) {
        self.userId = userId
        listener = db.collection("users").document(userId).collection("budgets")
            .whereField("monthStartDate", isEqualTo: monthStartDate)
            .order(by: "category")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching budgets: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.budgets = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.CategoryBudget.self)
                }
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
    
    func deleteBudget(id: String) async throws {
        guard let userId = userId else { return }
        try await db.collection("users").document(userId).collection("budgets").document(id).delete()
    }
    
    func calculateSpent(for category: String, transactions: [FirestoreModels.Transaction]) -> Double {
        return transactions
            .filter { $0.subtitle == category && $0.type == "expense" }
            .reduce(0) { $0 + abs($1.amount) }
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
        newGoal.createdAt = Date()
        try db.collection("users").document(userId).collection("savingGoals").document().setData(from: newGoal)
    }
    
    func updateSavingGoal(_ goal: FirestoreModels.SavingGoal) async throws {
        guard let userId = userId, let id = goal.id else { throw NSError(domain: "SavingGoalRepository", code: 400) }
        try db.collection("users").document(userId).collection("savingGoals").document(id).setData(from: goal)
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
}
