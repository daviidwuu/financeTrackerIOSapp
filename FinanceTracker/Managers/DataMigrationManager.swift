import Foundation
import FirebaseFirestore
import FirebaseAuth

/// One-off Data Migration Manager.
/// Iterates over historical Firestore documents and:
/// 1. Backfills `categoryId` on transactions using `subtitle` (category name) lookup.
/// 2. Removes legacy denormalized fields (`subtitle`, `icon`, `colorHex`, `fromName`, `toName`, `payerName`, `receiverName`).
///
/// Usage: Triggered from a hidden Developer Settings view. Run once, then remove.
class DataMigrationManager {
    
    private let db = Firestore.firestore()
    
    struct MigrationResult {
        var transactionsMigrated = 0
        var transactionsSkipped = 0
        var splitRequestsMigrated = 0
        var splitRequestsSkipped = 0
        var groupTransactionsMigrated = 0
        var groupTransactionsSkipped = 0
        var budgetsPrimed = 0
        var budgetsSkipped = 0
        var recurringTransactionsMigrated = 0
        var recurringTransactionsSkipped = 0
        var minorModelsMigrated = 0
        var minorModelsSkipped = 0
        var errors: [String] = []
        
        var summary: String {
            """
            Migration Complete!
            
            Transactions: \(transactionsMigrated) migrated, \(transactionsSkipped) skipped
            Split Requests: \(splitRequestsMigrated) migrated, \(splitRequestsSkipped) skipped
            Group Transactions: \(groupTransactionsMigrated) migrated, \(groupTransactionsSkipped) skipped
            Budgets Primed: \(budgetsPrimed) primed, \(budgetsSkipped) skipped
            Recurring Transactions: \(recurringTransactionsMigrated) migrated, \(recurringTransactionsSkipped) skipped
            Minor Models: \(minorModelsMigrated) migrated, \(minorModelsSkipped) skipped
            Errors: \(errors.count)
            """
        }
    }
    
    // MARK: - Full Migration
    
    /// Run the full migration pipeline.
    /// - Parameters:
    ///   - userId: The current user's UID (to scope the transaction query).
    ///   - categories: The user's current category list from BudgetRepository, used to map `subtitle` -> `categoryId`.
    /// - Returns: A `MigrationResult` summarizing what was done.
    func runFullMigration(
        userId: String,
        categories: [FirestoreModels.CategoryBudget]
    ) async -> MigrationResult {
        var result = MigrationResult()
        
        // Build a name -> id lookup dictionary for O(1) category matching
        var categoryLookup: [String: String] = [:]
        for cat in categories {
            categoryLookup[cat.category.lowercased()] = cat.id
        }
        
        // Phase 1: Migrate user transactions (backfill categoryId, remove subtitle/icon/colorHex)
        await migrateTransactions(userId: userId, categoryLookup: categoryLookup, result: &result)
        
        // Phase 2: Migrate split requests (remove fromName, toName)
        await migrateSplitRequests(userId: userId, result: &result)
        
        // Phase 3: Migrate group transactions (remove payerName, receiverName, category, icon, colorHex)
        await migrateGroupTransactions(userId: userId, result: &result)
        
        // Phase 4: Prime initial Cloud Function budget totals
        await primeBudgetTotals(userId: userId, categories: categories, result: &result)
        
        // Phase 5: Migrate recurring transactions (backfill categoryId, remove icon, colorHex)
        await migrateRecurringTransactions(userId: userId, categoryLookup: categoryLookup, result: &result)
        
        // Phase 6: Migrate minor social models (FriendRequests, GroupInvitations, EditRecords)
        await migrateMinorModels(userId: userId, result: &result)
        
        return result
    }
    
    // MARK: - Phase 1: Transactions
    
    private func migrateTransactions(
        userId: String,
        categoryLookup: [String: String],
        result: inout MigrationResult
    ) async {
        DebugLogger.log("📦 Migration Phase 1: Transactions")
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("transactions")
                .getDocuments()
            
            // Process in batches of 400 (Firestore limit is 500 per batch)
            let batchSize = 400
            let docs = snapshot.documents
            
            for batchStart in stride(from: 0, to: docs.count, by: batchSize) {
                let batch = db.batch()
                let batchEnd = min(batchStart + batchSize, docs.count)
                var batchCount = 0
                
                for i in batchStart..<batchEnd {
                    let doc = docs[i]
                    let data = doc.data()
                    
                    // Check if this doc still has legacy fields
                    let hasSubtitle = data["subtitle"] != nil
                    let hasLegacyIcon = data["icon"] != nil
                    let hasLegacyColor = data["colorHex"] != nil
                    let hasCategoryId = data["categoryId"] != nil
                    
                    // Skip if already fully migrated (no legacy fields AND has categoryId)
                    if !hasSubtitle && !hasLegacyIcon && !hasLegacyColor {
                        result.transactionsSkipped += 1
                        continue
                    }
                    
                    var updates: [String: Any] = [:]
                    var deletes: [String: Any] = [:]
                    
                    // Backfill categoryId if missing
                    if !hasCategoryId, let subtitle = data["subtitle"] as? String {
                        if let matchedId = categoryLookup[subtitle.lowercased()] {
                            updates["categoryId"] = matchedId
                        }
                    }
                    
                    // Mark legacy fields for deletion
                    if hasSubtitle { deletes["subtitle"] = FieldValue.delete() }
                    if hasLegacyIcon { deletes["icon"] = FieldValue.delete() }
                    if hasLegacyColor { deletes["colorHex"] = FieldValue.delete() }
                    
                    // Merge updates + deletes
                    let allUpdates = updates.merging(deletes) { _, new in new }
                    if !allUpdates.isEmpty {
                        batch.updateData(allUpdates, forDocument: doc.reference)
                        batchCount += 1
                    }
                }
                
                if batchCount > 0 {
                    try await batch.commit()
                    result.transactionsMigrated += batchCount
                    DebugLogger.log("✅ Transactions batch committed: \(batchCount) docs")
                }
            }
        } catch {
            let msg = "❌ Transaction migration error: \(error.localizedDescription)"
            DebugLogger.log(msg)
            result.errors.append(msg)
        }
    }
    
    // MARK: - Phase 2: Split Requests
    
    private func migrateSplitRequests(
        userId: String,
        result: inout MigrationResult
    ) async {
        DebugLogger.log("📦 Migration Phase 2: Split Requests")
        
        do {
            // Get all split requests where this user is the sender
            let fromSnapshot = try await db.collection("split_requests")
                .whereField("fromUid", isEqualTo: userId)
                .getDocuments()
            
            // Also get all split requests where this user is the receiver
            let toSnapshot = try await db.collection("split_requests")
                .whereField("toUid", isEqualTo: userId)
                .getDocuments()
            
            // Deduplicate docs
            var allDocs: [String: QueryDocumentSnapshot] = [:]
            for doc in fromSnapshot.documents { allDocs[doc.documentID] = doc }
            for doc in toSnapshot.documents { allDocs[doc.documentID] = doc }
            
            let docs = Array(allDocs.values)
            let batchSize = 400
            
            for batchStart in stride(from: 0, to: docs.count, by: batchSize) {
                let batch = db.batch()
                let batchEnd = min(batchStart + batchSize, docs.count)
                var batchCount = 0
                
                for i in batchStart..<batchEnd {
                    let doc = docs[i]
                    let data = doc.data()
                    
                    let hasFromName = data["fromName"] != nil
                    let hasToName = data["toName"] != nil
                    
                    if !hasFromName && !hasToName {
                        result.splitRequestsSkipped += 1
                        continue
                    }
                    
                    var deletes: [String: Any] = [:]
                    if hasFromName { deletes["fromName"] = FieldValue.delete() }
                    if hasToName { deletes["toName"] = FieldValue.delete() }
                    
                    batch.updateData(deletes, forDocument: doc.reference)
                    batchCount += 1
                }
                
                if batchCount > 0 {
                    try await batch.commit()
                    result.splitRequestsMigrated += batchCount
                    DebugLogger.log("✅ Split Requests batch committed: \(batchCount) docs")
                }
            }
        } catch {
            let msg = "❌ Split Requests migration error: \(error.localizedDescription)"
            DebugLogger.log(msg)
            result.errors.append(msg)
        }
    }
    
    // MARK: - Phase 3: Group Transactions
    
    private func migrateGroupTransactions(
        userId: String,
        result: inout MigrationResult
    ) async {
        DebugLogger.log("📦 Migration Phase 3: Group Transactions")
        
        do {
            // First, get all groups this user is a member of
            let groupsSnapshot = try await db.collection("groups")
                .whereField("members", arrayContains: userId)
                .getDocuments()
            
            for groupDoc in groupsSnapshot.documents {
                let groupId = groupDoc.documentID
                
                let txSnapshot = try await db.collection("groups")
                    .document(groupId)
                    .collection("transactions")
                    .getDocuments()
                
                let docs = txSnapshot.documents
                let batchSize = 400
                
                for batchStart in stride(from: 0, to: docs.count, by: batchSize) {
                    let batch = db.batch()
                    let batchEnd = min(batchStart + batchSize, docs.count)
                    var batchCount = 0
                    
                    for i in batchStart..<batchEnd {
                        let doc = docs[i]
                        let data = doc.data()
                        
                        let hasPayerName = data["payerName"] != nil
                        let hasReceiverName = data["receiverName"] != nil
                        let hasCategory = data["category"] != nil
                        let hasIcon = data["icon"] != nil
                        let hasColorHex = data["colorHex"] != nil
                        
                        if !hasPayerName && !hasReceiverName && !hasCategory && !hasIcon && !hasColorHex {
                            result.groupTransactionsSkipped += 1
                            continue
                        }
                        
                        var deletes: [String: Any] = [:]
                        if hasPayerName { deletes["payerName"] = FieldValue.delete() }
                        if hasReceiverName { deletes["receiverName"] = FieldValue.delete() }
                        if hasCategory { deletes["category"] = FieldValue.delete() }
                        if hasIcon { deletes["icon"] = FieldValue.delete() }
                        if hasColorHex { deletes["colorHex"] = FieldValue.delete() }
                        
                        batch.updateData(deletes, forDocument: doc.reference)
                        batchCount += 1
                    }
                    
                    if batchCount > 0 {
                        try await batch.commit()
                        result.groupTransactionsMigrated += batchCount
                        DebugLogger.log("✅ Group [\(groupId)] batch committed: \(batchCount) docs")
                    }
                }
            }
        } catch {
            let msg = "❌ Group Transaction migration error: \(error.localizedDescription)"
            DebugLogger.log(msg)
            result.errors.append(msg)
        }
    }
    
    // MARK: - Phase 4: Prime Budget Totals
    
    private func primeBudgetTotals(
        userId: String,
        categories: [FirestoreModels.CategoryBudget],
        result: inout MigrationResult
    ) async {
        DebugLogger.log("📦 Migration Phase 4: Priming Budget Totals")
        
        do {
            let batchSize = 400
            
            for batchStart in stride(from: 0, to: categories.count, by: batchSize) {
                let batch = db.batch()
                let batchEnd = min(batchStart + batchSize, categories.count)
                var batchCount = 0
                
                for i in batchStart..<batchEnd {
                    let budget = categories[i]
                    guard let budgetId = budget.id else { continue }
                    
                    // Skip if already primed by the cloud function (Checking dynamically since the model no longer defines it)
                    // We'll skip this optimization for the migration script and just blindly overwrite to ensure accuracy.
                    
                    // Manually calculate the window
                    let calculator = BudgetPeriodCalculator(calendar: Calendar.current, anchor: budget.monthStartDate)
                    let window = calculator.window(frequency: budget.frequency)
                    
                    // Query transactions for this budget within the window
                    let txSnapshot = try await db.collection("users")
                        .document(userId)
                        .collection("transactions")
                        .whereField("date", isGreaterThanOrEqualTo: window.start)
                        .whereField("date", isLessThan: window.end)
                        .getDocuments()
                    
                    let transactions = txSnapshot.documents.compactMap { try? $0.data(as: FirestoreModels.TransactionModel.self) }
                    
                    // Calculate and write the absolute spent amount
                    let spent = budget.spentAmount(transactions: transactions)
                    
                    let docRef = db.collection("users").document(userId).collection("budgets").document(budgetId)
                    batch.updateData([
                        "currentPeriodSpent": spent,
                        "lastAggregatedAt": FieldValue.serverTimestamp()
                    ], forDocument: docRef)
                    
                    batchCount += 1
                }
                
                if batchCount > 0 {
                    try await batch.commit()
                    result.budgetsPrimed += batchCount
                    DebugLogger.log("✅ Budgets batch primed: \(batchCount) docs")
                }
            }
        } catch {
            let msg = "❌ Budget Priming error: \(error.localizedDescription)"
            DebugLogger.log(msg)
            result.errors.append(msg)
        }
    }
    
    // MARK: - Phase 5: Recurring Transactions
    
    private func migrateRecurringTransactions(
        userId: String,
        categoryLookup: [String: String],
        result: inout MigrationResult
    ) async {
        DebugLogger.log("📦 Migration Phase 5: Recurring Transactions")
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("recurringTransactions")
                .getDocuments()
            
            let batchSize = 400
            let docs = snapshot.documents
            
            for batchStart in stride(from: 0, to: docs.count, by: batchSize) {
                let batch = db.batch()
                let batchEnd = min(batchStart + batchSize, docs.count)
                var batchCount = 0
                
                for i in batchStart..<batchEnd {
                    let doc = docs[i]
                    let data = doc.data()
                    
                    let hasCategoryId = data["categoryId"] != nil
                    let hasIcon = data["icon"] != nil
                    let hasColorHex = data["colorHex"] != nil
                    
                    if hasCategoryId && !hasIcon && !hasColorHex {
                        result.recurringTransactionsSkipped += 1
                        continue
                    }
                    
                    var updates: [String: Any] = [:]
                    var deletes: [String: Any] = [:]
                    
                    // Backfill categoryId using name
                    if !hasCategoryId, let name = data["name"] as? String {
                        if let matchedId = categoryLookup[name.lowercased()] {
                            updates["categoryId"] = matchedId
                        }
                    }
                    
                    if hasIcon { deletes["icon"] = FieldValue.delete() }
                    if hasColorHex { deletes["colorHex"] = FieldValue.delete() }
                    
                    let allUpdates = updates.merging(deletes) { _, new in new }
                    if !allUpdates.isEmpty {
                        batch.updateData(allUpdates, forDocument: doc.reference)
                        batchCount += 1
                    }
                }
                
                if batchCount > 0 {
                    try await batch.commit()
                    result.recurringTransactionsMigrated += batchCount
                    DebugLogger.log("✅ Recurring Transactions batch committed: \(batchCount) docs")
                }
            }
        } catch {
            let msg = "❌ Recurring Transaction migration error: \(error.localizedDescription)"
            DebugLogger.log(msg)
            result.errors.append(msg)
        }
    }
    
    // MARK: - Phase 6: Minor Social Models
    
    private func migrateMinorModels(
        userId: String,
        result: inout MigrationResult
    ) async {
        DebugLogger.log("📦 Migration Phase 6: Minor Social Models")
        
        // 1. Friend Requests (sent or received by user)
        do {
            let fromSnapshot = try await db.collection("friend_requests").whereField("fromUid", isEqualTo: userId).getDocuments()
            let toSnapshot = try await db.collection("friend_requests").whereField("toUid", isEqualTo: userId).getDocuments()
            
            var allDocs: [String: QueryDocumentSnapshot] = [:]
            for doc in fromSnapshot.documents { allDocs[doc.documentID] = doc }
            for doc in toSnapshot.documents { allDocs[doc.documentID] = doc }
            
            let docs = Array(allDocs.values)
            let batchSize = 400
            
            for batchStart in stride(from: 0, to: docs.count, by: batchSize) {
                let batch = db.batch()
                let batchEnd = min(batchStart + batchSize, docs.count)
                var batchCount = 0
                
                for i in batchStart..<batchEnd {
                    let doc = docs[i]
                    let data = doc.data()
                    
                    let hasFromName = data["fromName"] != nil
                    let hasFromUsername = data["fromUsername"] != nil
                    
                    if !hasFromName && !hasFromUsername {
                        result.minorModelsSkipped += 1
                        continue
                    }
                    
                    var deletes: [String: Any] = [:]
                    if hasFromName { deletes["fromName"] = FieldValue.delete() }
                    if hasFromUsername { deletes["fromUsername"] = FieldValue.delete() }
                    
                    batch.updateData(deletes, forDocument: doc.reference)
                    batchCount += 1
                }
                
                if batchCount > 0 {
                    try await batch.commit()
                    result.minorModelsMigrated += batchCount
                    DebugLogger.log("✅ Friend Requests batch committed: \(batchCount) docs")
                }
            }
        } catch {
            DebugLogger.log("❌ Friend Requests migration error: \(error.localizedDescription)")
            result.errors.append(error.localizedDescription)
        }
        
        // 2. Group Invitations
        do {
            let fromSnapshot = try await db.collection("group_invitations").whereField("fromUid", isEqualTo: userId).getDocuments()
            let toSnapshot = try await db.collection("group_invitations").whereField("toUid", isEqualTo: userId).getDocuments()
            
            var allDocs: [String: QueryDocumentSnapshot] = [:]
            for doc in fromSnapshot.documents { allDocs[doc.documentID] = doc }
            for doc in toSnapshot.documents { allDocs[doc.documentID] = doc }
            
            let docs = Array(allDocs.values)
            let batchSize = 400
            
            for batchStart in stride(from: 0, to: docs.count, by: batchSize) {
                let batch = db.batch()
                let batchEnd = min(batchStart + batchSize, docs.count)
                var batchCount = 0
                
                for i in batchStart..<batchEnd {
                    let doc = docs[i]
                    let data = doc.data()
                    
                    let hasGroupName = data["groupName"] != nil
                    
                    if !hasGroupName {
                        result.minorModelsSkipped += 1
                        continue
                    }
                    
                    batch.updateData(["groupName": FieldValue.delete()], forDocument: doc.reference)
                    batchCount += 1
                }
                
                if batchCount > 0 {
                    try await batch.commit()
                    result.minorModelsMigrated += batchCount
                    DebugLogger.log("✅ Group Invitations batch committed: \(batchCount) docs")
                }
            }
        } catch {
            DebugLogger.log("❌ Group Invitations migration error: \(error.localizedDescription)")
            result.errors.append(error.localizedDescription)
        }
        
        // 3. Edit History on Transactions
        do {
            let snapshot = try await db.collection("users").document(userId).collection("transactions").getDocuments()
            let docs = snapshot.documents
            let batchSize = 400
            
            for batchStart in stride(from: 0, to: docs.count, by: batchSize) {
                let batch = db.batch()
                let batchEnd = min(batchStart + batchSize, docs.count)
                var batchCount = 0
                
                for i in batchStart..<batchEnd {
                    let doc = docs[i]
                    let data = doc.data()
                    
                    guard let editHistory = data["editHistory"] as? [[String: Any]], !editHistory.isEmpty else {
                        result.minorModelsSkipped += 1
                        continue
                    }
                    
                    var needsMigration = false
                    var cleanedHistory: [[String: Any]] = []
                    
                    for var record in editHistory {
                        if record["editorName"] != nil {
                            record.removeValue(forKey: "editorName")
                            needsMigration = true
                        }
                        cleanedHistory.append(record)
                    }
                    
                    if !needsMigration {
                        result.minorModelsSkipped += 1
                        continue
                    }
                    
                    batch.updateData(["editHistory": cleanedHistory], forDocument: doc.reference)
                    batchCount += 1
                }
                
                if batchCount > 0 {
                    try await batch.commit()
                    result.minorModelsMigrated += batchCount
                    DebugLogger.log("✅ Transaction Edit History batch committed: \(batchCount) docs")
                }
            }
        } catch {
            DebugLogger.log("❌ Transaction Edit History migration error: \(error.localizedDescription)")
            result.errors.append(error.localizedDescription)
        }
        
        // 4. Edit History on Group Transactions
        do {
            let groupsSnapshot = try await db.collection("groups").whereField("members", arrayContains: userId).getDocuments()
            for groupDoc in groupsSnapshot.documents {
                let txSnapshot = try await db.collection("groups").document(groupDoc.documentID).collection("transactions").getDocuments()
                let docs = txSnapshot.documents
                let batchSize = 400
                
                for batchStart in stride(from: 0, to: docs.count, by: batchSize) {
                    let batch = db.batch()
                    let batchEnd = min(batchStart + batchSize, docs.count)
                    var batchCount = 0
                    
                    for i in batchStart..<batchEnd {
                        let doc = docs[i]
                        let data = doc.data()
                        
                        guard let editHistory = data["editHistory"] as? [[String: Any]], !editHistory.isEmpty else {
                            result.minorModelsSkipped += 1
                            continue
                        }
                        
                        var needsMigration = false
                        var cleanedHistory: [[String: Any]] = []
                        
                        for var record in editHistory {
                            if record["editorName"] != nil {
                                record.removeValue(forKey: "editorName")
                                needsMigration = true
                            }
                            cleanedHistory.append(record)
                        }
                        
                        if !needsMigration {
                            result.minorModelsSkipped += 1
                            continue
                        }
                        
                        batch.updateData(["editHistory": cleanedHistory], forDocument: doc.reference)
                        batchCount += 1
                    }
                    
                    if batchCount > 0 {
                        try await batch.commit()
                        result.minorModelsMigrated += batchCount
                        DebugLogger.log("✅ Group Transaction Edit History batch committed: \(batchCount) docs")
                    }
                }
            }
        } catch {
            DebugLogger.log("❌ Group Transaction Edit History migration error: \(error.localizedDescription)")
            result.errors.append(error.localizedDescription)
        }
    }
}
