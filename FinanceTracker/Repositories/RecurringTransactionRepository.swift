import Foundation
import FirebaseFirestore
import Combine

/// Repository for managing recurring transactions in Firestore
class RecurringTransactionRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var recurringTransactions: [FirestoreModels.RecurringTransaction] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var userId: String?
    
    private var listener: ListenerRegistration?
    
    func startListening(userId: String) {
        self.userId = userId
        self.isLoading = true
        self.errorMessage = nil
        
        listener = db.collection("users").document(userId).collection("recurringTransactions")
            .order(by: "startDate")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error fetching recurring transactions: \(error.localizedDescription)"
                    DebugLogger.log("Error fetching recurring transactions: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No recurring transactions found."
                    return
                }
                
                self.errorMessage = nil
                self.recurringTransactions = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.RecurringTransaction.self)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
        recurringTransactions = []
    }
    
    func addRecurringTransaction(_ transaction: FirestoreModels.RecurringTransaction) async throws {
        guard let userId = userId else { return }
        var newTransaction = transaction
        newTransaction.createdAt = Date()
        try db.collection("users").document(userId).collection("recurringTransactions").document().setData(from: newTransaction)
        
        // Gamification
        DispatchQueue.main.async {
            GamificationManager.shared.completeMission(id: "subscription_tracker")
        }
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
    // DEPRECATED: Logic moved to Backend Cloud Function (scheduled)
    // Only keeping empty function signature to avoid breaking call sites immediately
    func processDueTransactions(userId: String) async {
        DebugLogger.log("Recurring transactions are now handled by the backend.")
        return
    }
}
