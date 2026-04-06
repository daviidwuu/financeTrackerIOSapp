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
        // Only show loading if we don't have any data yet (Stale-While-Revalidate)
        if recurringTransactions.isEmpty {
            self.isLoading = true
        }
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
                    do {
                        return try document.data(as: FirestoreModels.RecurringTransaction.self)
                    } catch {
                        DebugLogger.log("Failed to decode RecurringTransaction (\(document.documentID)): \(error)")
                        return nil
                    }
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
    
    /// Client-side fallback: auto-log any recurring transactions that are due but not yet
    /// recorded. This guards against the backend Cloud Function being delayed or missed.
    ///
    /// Logic:
    /// - Skip any recurring entry whose `lastProcessedDate` is within the last 2 days
    ///   (the backend likely already ran and created those transactions).
    /// - Look back up to 30 days for each remaining entry and auto-log any unrecorded
    ///   occurrences (duplicate detection matches by date + title + amount, same as the
    ///   missed-occurrence UI so there is no double-counting).
    /// - After processing, stamp `lastProcessedDate = today` so this won't re-run
    ///   until the next gap appears.
    func processDueTransactions(userId: String, transactionRepo: TransactionRepository) async {
        // Guard: ensure this repository is still listening for the same user.
        // The gap-fill task sleeps 3 s before running; the user may have logged out
        // or switched accounts in that window.
        guard self.userId == userId else {
            DebugLogger.log("processDueTransactions: skipped — userId mismatch (expected \(userId), have \(self.userId ?? "nil"))")
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Only auto-log up to 30 days back to avoid mass-creating historical transactions
        let maxLookback = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        // Consider the backend "recent" if it ran within the last 2 days
        let recentThreshold = calendar.date(byAdding: .day, value: -2, to: today) ?? today

        for recurring in recurringTransactions {
            // Skip if the backend processed this recently
            if let lastProcessed = recurring.lastProcessedDate,
               calendar.startOfDay(for: lastProcessed) >= recentThreshold {
                continue
            }

            // Find missed occurrences within the lookback window (handles duplicate detection)
            let missed = WalletLogic.calculateMissedOccurrences(
                recurring: recurring,
                loggedTransactions: transactionRepo.allTransactions,
                fromDate: maxLookback
            )

            let type = recurring.type ?? "expense"
            var allWritesSucceeded = true

            for date in missed {
                let amount = (type == "income") ? abs(recurring.amount) : -abs(recurring.amount)
                let note = "Auto: \(recurring.frequency)" +
                    ((recurring.note?.isEmpty == false) ? " - \(recurring.note!)" : "")

                let newTx = FirestoreModels.TransactionModel(
                    userId: userId,
                    title: recurring.name,
                    categoryId: recurring.categoryId,
                    amount: amount,
                    date: date,
                    type: type,
                    createdAt: Date(),
                    note: note,
                    source: "subscription"
                )

                do {
                    try await transactionRepo.addTransaction(newTx)
                } catch {
                    allWritesSucceeded = false
                    DebugLogger.log("processDueTransactions: failed to log '\(recurring.name)' on \(date): \(error.localizedDescription)")
                }
            }

            // Only stamp lastProcessedDate when all writes succeeded.
            // If any write failed the entry will be retried on the next app launch.
            if allWritesSucceeded {
                var updated = recurring
                updated.lastProcessedDate = today
                do {
                    try await updateRecurringTransaction(updated)
                } catch {
                    DebugLogger.log("processDueTransactions: failed to update lastProcessedDate for '\(recurring.name)': \(error.localizedDescription)")
                }
            }
        }

        DebugLogger.log("processDueTransactions: finished client-side gap-fill for \(recurringTransactions.count) recurring entries.")
    }
}
