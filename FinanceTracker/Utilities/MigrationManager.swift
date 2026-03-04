import Foundation
import FirebaseFirestore
import FirebaseAuth

class MigrationManager {
    static let shared = MigrationManager()
    private let db = Firestore.firestore()
    
    // Migration Keys
    private let kMigratedSalaryToIncome = "hasMigratedSalaryToIncome_v1"
    private let kMigratedCategoryIcons = "hasMigratedCategoryIcons_v1"
    private let kMigratedSplitStatus = "hasMigratedSplitStatus_v1"
    private let kMigratedSettlementStatus = "hasMigratedSettlementStatus_v1"
    private let kMigratedNilCurrency = "hasMigratedNilCurrency_v1"
    private let kClearedPendingDeleteIds = "hasClearedPendingDeleteIds_v1"
    private let kMigratedUserAvatarColor = "hasMigratedUserAvatarColor_v1"

    private init() {}

    func checkForMigrations() {
        // Local-only migration (no userId required)
        clearCorruptedPendingDeleteIds()

        guard let userId = Auth.auth().currentUser?.uid else { return }

        Task {
            await migrateSalaryToIncome(userId: userId)
            await migrateCategoryIcons(userId: userId)
            await migrateSplitStatusToEnum(userId: userId)
            await migrateSettlementStatus(userId: userId)
            await migrateNilCurrencySplits(userId: userId)
            await migrateUserAvatarColor(userId: userId)
        }
    }

    // MARK: - Clear Corrupted Pending Delete IDs (#17 Hotfix)
    /// Clears the legacy pendingOptimisticDeleteIds UserDefaults key that was causing
    /// transactions to permanently disappear. This key is no longer used (reverted to in-memory only).
    private func clearCorruptedPendingDeleteIds() {
        if UserDefaults.standard.bool(forKey: kClearedPendingDeleteIds) { return }

        if let staleIds = UserDefaults.standard.stringArray(forKey: "pendingOptimisticDeleteIds"), !staleIds.isEmpty {
            DebugLogger.log("🔧 Clearing \(staleIds.count) corrupted pendingOptimisticDeleteIds from UserDefaults")
            UserDefaults.standard.removeObject(forKey: "pendingOptimisticDeleteIds")
        }

        UserDefaults.standard.set(true, forKey: kClearedPendingDeleteIds)
    }
    
    private func migrateCategoryIcons(userId: String) async {
        if UserDefaults.standard.bool(forKey: kMigratedCategoryIcons) {
            return
        }
        
        do {
            let snapshot = try await db.collection("users").document(userId).collection("budgets").getDocuments()
            let batch = db.batch()
            var updateCount = 0
            
            for document in snapshot.documents {
                let data = document.data()
                let icon = data["icon"] as? String
                let colorHex = data["colorHex"] as? String
                
                var updateData: [String: Any] = [:]
                if icon == nil || icon?.isEmpty == true {
                    updateData["icon"] = "tag.fill"
                }
                if colorHex == nil || colorHex?.isEmpty == true {
                    updateData["colorHex"] = "#808080"
                }
                
                if !updateData.isEmpty {
                    batch.updateData(updateData, forDocument: document.reference)
                    updateCount += 1
                }
            }
            
            if updateCount > 0 {
                try await batch.commit()
                DebugLogger.log("Migration: Backfilled icons/colors for \(updateCount) categories.")
            }
            
            UserDefaults.standard.set(true, forKey: kMigratedCategoryIcons)
            
        } catch {
            DebugLogger.log("Migration Failed (CategoryIcons): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Split Status Enum Migration (#12)
    /// Backfills `splitStatus` on existing transaction splits that only have legacy isPaid/isAccepted/status fields.
    private func migrateSplitStatusToEnum(userId: String) async {
        if UserDefaults.standard.bool(forKey: kMigratedSplitStatus) { return }

        do {
            let snapshot = try await db.collection("users").document(userId).collection("transactions")
                .whereField("splits", isNotEqualTo: NSNull())
                .getDocuments()

            let batch = db.batch()
            var updateCount = 0

            for document in snapshot.documents {
                guard var splits = document.data()["splits"] as? [[String: Any]] else { continue }
                var needsUpdate = false

                for i in 0..<splits.count {
                    if splits[i]["splitStatus"] == nil {
                        // Derive from legacy fields
                        let isPaid = splits[i]["isPaid"] as? Bool ?? false
                        let isAccepted = splits[i]["isAccepted"] as? Bool ?? false
                        let status = splits[i]["status"] as? String

                        let derivedStatus: String
                        if let status = status, ["pending", "accepted", "declined", "paid"].contains(status) {
                            derivedStatus = status
                        } else if isPaid {
                            derivedStatus = "paid"
                        } else if isAccepted {
                            derivedStatus = "accepted"
                        } else {
                            derivedStatus = "pending"
                        }

                        splits[i]["splitStatus"] = derivedStatus
                        needsUpdate = true
                    }
                }

                if needsUpdate {
                    batch.updateData(["splits": splits], forDocument: document.reference)
                    updateCount += 1
                }
            }

            if updateCount > 0 {
                try await batch.commit()
                DebugLogger.log("Migration: Backfilled splitStatus for \(updateCount) transactions.")
            }

            UserDefaults.standard.set(true, forKey: kMigratedSplitStatus)
        } catch {
            DebugLogger.log("Migration Failed (SplitStatus): \(error.localizedDescription)")
        }
    }

    // MARK: - Settlement Status Migration (#31)
    /// Old settlement requests were created with status .paid; new ones start as .pending.
    /// This normalizes old settlements so filtering by status is consistent.
    private func migrateSettlementStatus(userId: String) async {
        if UserDefaults.standard.bool(forKey: kMigratedSettlementStatus) { return }

        do {
            // Find settlements created by this user that are immediately .paid (old behavior)
            let snapshot = try await db.collection("split_requests")
                .whereField("fromUid", isEqualTo: userId)
                .whereField("isSettlement", isEqualTo: true)
                .whereField("status", isEqualTo: "paid")
                .getDocuments()

            // No batch needed if nothing found
            if snapshot.documents.isEmpty {
                UserDefaults.standard.set(true, forKey: kMigratedSettlementStatus)
                return
            }

            // Note: We do NOT change old settlements to pending — they were already accepted implicitly.
            // We just mark this migration as done. The key fix is that NEW settlements start as .pending.
            UserDefaults.standard.set(true, forKey: kMigratedSettlementStatus)
            DebugLogger.log("Migration: Settlement status check complete. \(snapshot.documents.count) old settlements remain as paid.")
        } catch {
            DebugLogger.log("Migration Failed (SettlementStatus): \(error.localizedDescription)")
        }
    }

    // MARK: - Nil Currency Migration (#9)
    /// Backfills nil currency fields on old split requests with the user's main currency.
    private func migrateNilCurrencySplits(userId: String) async {
        if UserDefaults.standard.bool(forKey: kMigratedNilCurrency) { return }

        do {
            let mainCurrency = CurrencyManager.shared.mainCurrency

            // Find split requests created by this user with no currency
            let snapshot = try await db.collection("split_requests")
                .whereField("fromUid", isEqualTo: userId)
                .getDocuments()

            let batch = db.batch()
            var updateCount = 0

            for document in snapshot.documents {
                if document.data()["currency"] == nil || (document.data()["currency"] as? String) == nil {
                    batch.updateData(["currency": mainCurrency], forDocument: document.reference)
                    updateCount += 1
                }
            }

            if updateCount > 0 {
                try await batch.commit()
                DebugLogger.log("Migration: Backfilled currency for \(updateCount) split requests.")
            }

            UserDefaults.standard.set(true, forKey: kMigratedNilCurrency)
        } catch {
            DebugLogger.log("Migration Failed (NilCurrency): \(error.localizedDescription)")
        }
    }

    // MARK: - User Avatar Color Migration
    /// Backfills avatarColor on user profiles that don't have one yet.
    /// Sets default to orange (#FF9500) to maintain consistency with existing UI.
    private func migrateUserAvatarColor(userId: String) async {
        if UserDefaults.standard.bool(forKey: kMigratedUserAvatarColor) { return }

        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()

            guard userDoc.exists else {
                UserDefaults.standard.set(true, forKey: kMigratedUserAvatarColor)
                return
            }

            let data = userDoc.data() ?? [:]

            // Only update if avatarColor is missing
            if data["avatarColor"] == nil || (data["avatarColor"] as? String) == nil {
                try await db.collection("users").document(userId).updateData([
                    "avatarColor": "#FF9500" // Default orange color
                ])
                DebugLogger.log("Migration: Set default avatarColor for user \(userId)")
            }

            UserDefaults.standard.set(true, forKey: kMigratedUserAvatarColor)
        } catch {
            DebugLogger.log("Migration Failed (UserAvatarColor): \(error.localizedDescription)")
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
