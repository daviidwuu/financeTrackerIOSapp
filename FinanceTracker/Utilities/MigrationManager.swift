import Foundation
import FirebaseFirestore
import FirebaseAuth

class MigrationManager {
    static let shared = MigrationManager()
    private let db = Firestore.firestore()
    
    // Migration Keys
    private let kMigratedSalaryToIncome = "hasMigratedSalaryToIncome_v1"
    
    private init() {}
    
    func checkForMigrations() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            await migrateSalaryToIncome(userId: userId)
        }
    }
    
    private func migrateSalaryToIncome(userId: String) async {
        // Check if already migrated
        if UserDefaults.standard.bool(forKey: kMigratedSalaryToIncome) {
            return
        }
        
        do {
            // 1. Fetch all recurring transactions for the user
            let snapshot = try await db.collection("users").document(userId).collection("recurringTransactions")
                .whereField("name", isEqualTo: "Salary")
                .getDocuments()
            
            let batch = db.batch()
            var updateCount = 0
            
            for document in snapshot.documents {
                // Double check if name is Salary (redundant with query but safe)
                // Update Name to "Income" and Note to "Salary"
                let ref = document.reference
                batch.updateData([
                    "name": "Income",
                    "note": "Salary"
                ], forDocument: ref)
                updateCount += 1
            }
            
            if updateCount > 0 {
                try await batch.commit()
                DebugLogger.log("Migration: Updated \(updateCount) Salary transactions to Income.")
            } else {
                DebugLogger.log("Migration: No Salary transactions found to update.")
            }
            
            // Mark as done
            UserDefaults.standard.set(true, forKey: kMigratedSalaryToIncome)
            
        } catch {
            DebugLogger.log("Migration Failed: \(error.localizedDescription)")
        }
    }
}
