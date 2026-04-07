import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Manages complex social transaction logic: Batch writes for Transaction, SplitRequests, FriendRequests, and GroupInvitations.
class SocialTransactionManager: ObservableObject {
    static let shared = SocialTransactionManager()
    let db = Firestore.firestore()
    
    private init() {}
    
    // FIX #18: Reusable retry helper with exponential backoff
    func withRetry<T>(maxAttempts: Int = 3, initialDelay: TimeInterval = 1.0, operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = initialDelay * pow(2.0, Double(attempt))
                    DebugLogger.log("Retry attempt \(attempt + 1)/\(maxAttempts) after \(delay)s: \(error.localizedDescription)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError!
    }
    
    /// Nudges a user for a pending split request.
    func nudgeSplitRequest(request: FirestoreModels.SplitRequest) async throws {
        guard let requestId = request.id else { return }
        
        let requestRef = db.collection("split_requests").document(requestId)
        try await requestRef.updateData([
            "lastNudgedAt": Date()
        ])
    }

    
    /// Creates a social transaction with all necessary dependent documents in a single atomic batch.
    /// - Parameters:
    ///   - transaction: The transaction to save (transaction.splits should be populated).
    ///   - payerUid: The ID of the user paying (usually current user).
    ///   - payerName: The name of the payer.
    ///   - groupId: Optional ID of the group this transaction belongs to.
    ///   - friendCache: Local cache of friends to avoid redundant reads.
    ///   - groupCache: Local cache of groups to check membership.
    @discardableResult
    func createSocialTransaction(
        transaction: FirestoreModels.TransactionModel,
        payerUid: String,
        payerName: String,
        groupId: String?,
        friendCache: [FirestoreModels.Friend],
        groupCache: [FirestoreModels.Group]
    ) async throws -> FirestoreModels.TransactionModel {
        
        DebugLogger.log("🔍 createSocialTransaction called with payerName: '\(payerName)', payerUid: '\(payerUid)'")
        
        let batch = db.batch()
        
        // 1. Transaction Reference
        let transactionRef: DocumentReference
        if let id = transaction.id {
            transactionRef = db.collection("users").document(payerUid).collection("transactions").document(id)
        } else {
            transactionRef = db.collection("users").document(payerUid).collection("transactions").document()
        }
        
        var finalTransaction = transaction
        finalTransaction.id = transactionRef.documentID // Ensure ID is set
        finalTransaction.userId = payerUid // Ensure owner
        finalTransaction.source = "social_v2" // ✅ Mark as v2.1 to prevent legacy trigger duplication
        
        // --- 1.5. Prepare Existing Data for UPSERT (Avoid Delete-All) ---
        // Fetch all existing requests for this transaction
        var existingRequestsDocs: [QueryDocumentSnapshot] = []
        if let snapshot = try? await db.collection("split_requests")
            .whereField("transactionId", isEqualTo: transactionRef.documentID)
            .whereField("fromUid", isEqualTo: payerUid)
            .getDocuments() {
            existingRequestsDocs = snapshot.documents
        }
        
        // OPTIMIZATION: Convert array to dictionary for O(1) lookups
        var existingRequestsByUid: [String: QueryDocumentSnapshot] = [:]
        for doc in existingRequestsDocs {
            if let uid = (doc.get("toUid") as? String) ?? (doc.data()["toUid"] as? String) {
                existingRequestsByUid[uid] = doc
            }
        }
        
        // 2. Process Splits & Requests
        let updatedSplits = finalTransaction.splits ?? []
        
        // --- 2a. Determine Currency Logic ---
        let mainCurrency = CurrencyManager.shared.mainCurrency
        
        // Cache group lookup
        let targetGroup = groupId.flatMap { id in groupCache.first { $0.id == id } }
        let groupMembersSet = Set(targetGroup?.members ?? [])
        
        // Target Currency: The currency the GROUP uses (Default or Main)
        var targetCurrency = mainCurrency
        if let groupCurrency = targetGroup?.defaultCurrency {
            targetCurrency = groupCurrency
        }
        
        // Source Currency: The currency of the TRANSACTION
        // If the transaction carries foreign metadata (Home-style), the stored amount is mainCurrency.
        let hasForeignMetadata = finalTransaction.currencyCode != nil && finalTransaction.originalAmount != nil && finalTransaction.exchangeRate != nil
        let sourceCurrency = hasForeignMetadata ? mainCurrency : (finalTransaction.currencyCode ?? mainCurrency)
        
        // Conversion Rate: Source -> Target
        // FIX 1.1: Use universal getRate instead of narrow travelCurrency→mainCurrency check
        var conversionRate: Double = 1.0
        if sourceCurrency != targetCurrency {
            if !hasForeignMetadata, let txRate = finalTransaction.exchangeRate {
                // Transaction has a manually-specified exchange rate (user override)
                conversionRate = txRate
            } else {
                // Use CurrencyManager's universal rate lookup (supports any pair via allRates)
                conversionRate = CurrencyManager.shared.getRate(from: sourceCurrency, to: targetCurrency)
            }
        }
        
        for split in updatedSplits {
            // Skip self and guests (unless we want to track guests in a separate collection later)
            // Skip self
            if split.friendId == payerUid { continue }
            
            var targetUid: String?
            let targetName = split.name

            if split.isGuest {
                targetUid = split.guestId // Use Guest ID
            } else {
                targetUid = split.friendId // Use Friend ID
            }
            
            guard let friendUid = targetUid else { continue }
            
            // --- Step B: Group Invitation Logic ---
            let dependencyId: String? = nil
            var requestStatus: FirestoreModels.SplitRequest.RequestStatus = .pending
            
            if targetGroup != nil {
                if !groupMembersSet.contains(friendUid) {
                    // Check if invite already exists? 
                    // For simplicity, we just create a request that might be "blocked_by_group" if we enforced it,
                    // but here we just create a split request.
                    // Ideally we would create an invitation here.
                    // check if invitation exists logic would stay here...
                    // Skipping complex invitation logic to fix build error first, relying on basic split request.
                }
            }
            
            // --- Step C: Create/Update Split Request ---
            let requestRef: DocumentReference
            
            // Look for a matching document in our fetched list
            if let existingDoc = existingRequestsByUid[friendUid] {
                // FOUND: Reuse this document
                requestRef = existingDoc.reference
                
                // Remove from dictionary so we don't delete it later
                existingRequestsByUid.removeValue(forKey: friendUid)
                
                // Preserve status if amount is same
                if let existingAmount = existingDoc.get("amount") as? Double, abs(existingAmount - split.amount) < 0.01 {
                    if let statusStr = existingDoc.get("status") as? String, let status = FirestoreModels.SplitRequest.RequestStatus(rawValue: statusStr) {
                         requestStatus = status
                    }
                }
            } else {
                // NOT FOUND: Create new
                requestRef = db.collection("split_requests").document()
            }
            
            let splitRequest = FirestoreModels.SplitRequest(
                id: nil, // Firestore ID
                transactionId: finalTransaction.id!,
                groupId: groupId,
                fromUid: payerUid,
                toUid: friendUid,
                fromName: payerName,
                toName: targetName, // ✅ Store Receiver Name
                amount: split.amount,
                currency: sourceCurrency, // Request is in Source Currency (transaction currency)
                note: (finalTransaction.note?.isEmpty == false) ? finalTransaction.note : finalTransaction.title, // ✅ Prioritize Note ("Burger King") over Title ("Food")
                category: finalTransaction.subtitle, // ✅ FIX: Category name (populated by caller)
                icon: finalTransaction.icon,          // ✅ FIX: Icon (populated by caller)
                colorHex: finalTransaction.colorHex,  // ✅ FIX: Color (populated by caller)
                status: requestStatus,
                dependencyId: dependencyId,
                lastNudgedAt: nil,
                originalTotalAmount: abs(finalTransaction.amount), // ✅ Full pre-split expense total
                isGuest: split.isGuest, // FIX 3.5: Propagate guest flag
                isSettlement: nil,
                latitude: finalTransaction.latitude,
                longitude: finalTransaction.longitude,
                createdAt: Date()
            )
            
            try batch.setData(from: splitRequest, forDocument: requestRef)
            
            // Update the split in the transaction with the linked request ID
            if let index = finalTransaction.splits?.firstIndex(where: { $0.id == split.id }) {
                finalTransaction.splits?[index].requestId = requestRef.documentID
            }
        }
        
        // 3. Save the Transaction Itself
        
        // --- PRE-SAVE MERGE & CHANGE TRACKING ---
        // Fetch latest version from server to ensure we don't overwrite a concurrent "Mark as Paid"
        var remoteSplits: [FirestoreModels.Split]? = nil
        
        if let existingTxSnapshot = try? await transactionRef.getDocument(),
           existingTxSnapshot.exists,
           let remoteTx = try? existingTxSnapshot.data(as: FirestoreModels.TransactionModel.self) {
            
            remoteSplits = remoteTx.splits
            
            // --- 1. Track Changes (Audit Trail) ---
            var history = remoteTx.editHistory ?? []
            var hasChanges = false
            
            // Check Amount
            if abs(remoteTx.amount - finalTransaction.amount) > 0.01 {
                let oldVal = String(format: "%.2f", remoteTx.amount)
                let newVal = String(format: "%.2f", finalTransaction.amount)
                history.append(FirestoreModels.EditRecord(
                    date: Date(),
                    editorId: payerUid,
                    editorName: payerName,
                    field: "amount",
                    oldValue: oldVal,
                    newValue: newVal
                ))
                hasChanges = true
            }
            
            // Check Title
            if remoteTx.title != finalTransaction.title {
                history.append(FirestoreModels.EditRecord(
                    date: Date(),
                    editorId: payerUid,
                    editorName: payerName,
                    field: "title",
                    oldValue: remoteTx.title,
                    newValue: finalTransaction.title
                ))
                hasChanges = true
            }
            
            if hasChanges {
                // Limit history to last 5 entries to save space
                if history.count > 5 {
                    history = Array(history.suffix(5))
                }
                finalTransaction.editHistory = history
            } else {
                // Keep existing history if no new changes
                finalTransaction.editHistory = remoteTx.editHistory
            }

            // --- 2. Merge Remote Splits (Safety Merge) ---
            if let remoteSplits = remoteTx.splits {
            
            // Merge remote status into local splits
            if var localSplits = finalTransaction.splits {
                // Optimize remoteSplit lookup
                var remoteSplitsDict: [String: FirestoreModels.Split] = [:]
                for split in remoteSplits {
                    remoteSplitsDict[split.id] = split
                }
                
                for i in 0..<localSplits.count {
                    let localSplit = localSplits[i]
                    // First try fast ID lookup, then fallback to friendId+amount match
                    var remoteSplit: FirestoreModels.Split? = remoteSplitsDict[localSplit.id]
                    if remoteSplit == nil {
                        remoteSplit = remoteSplits.first(where: { $0.friendId == localSplit.friendId && $0.amount == localSplit.amount })
                    }
                    
                    if let remoteSplit = remoteSplit {

                        // FIX #13: Bidirectional merge — preserve whichever side has the more advanced status.
                        // Use paidDate as tiebreaker when both have been modified.
                        if remoteSplit.isPaid && !localSplit.isPaid {
                            DebugLogger.log("Safety Merge: Preserving PAID status for \(localSplit.name) from remote.")
                            localSplits[i].isPaid = true
                            localSplits[i].paidDate = remoteSplit.paidDate
                            localSplits[i].incomeTransactionId = remoteSplit.incomeTransactionId
                        } else if localSplit.isPaid && !remoteSplit.isPaid {
                            // Local is paid but remote isn't — keep local paid status
                            DebugLogger.log("Safety Merge: Preserving PAID status for \(localSplit.name) from local.")
                            // localSplit already has the right status, no changes needed
                        }

                        // Merge status: pick the more advanced status
                        let statusPriority: [FirestoreModels.SplitStatus: Int] = [.pending: 0, .accepted: 1, .declined: 1, .paid: 2]
                        let remotePriority = statusPriority[remoteSplit.splitStatus] ?? 0
                        let localPriority = statusPriority[localSplit.splitStatus] ?? 0
                        if remotePriority > localPriority {
                            DebugLogger.log("Safety Merge: Preserving status '\(remoteSplit.splitStatus.rawValue)' for \(localSplit.name) from remote.")
                            localSplits[i].splitStatus = remoteSplit.splitStatus
                        }
                    }
                }
                finalTransaction.splits = localSplits
            }
        }
        }
        // -------------------------------------------

        try batch.setData(from: finalTransaction, forDocument: transactionRef)
        
        // 4. Cleanup Removed Splits (Any docs left in existingRequestsByUid are orphans)
        for doc in existingRequestsByUid.values {
            batch.deleteDocument(doc.reference)
            
            // Also clean up any income transaction created for this removed split
            let uid = (doc.get("toUid") as? String) ?? (doc.data()["toUid"] as? String)
            
            if let uid = uid, let originalSplits = remoteSplits {
                 if let removedSplit = originalSplits.first(where: {
                    $0.friendId == uid || $0.guestId == uid
                }), let incomeId = removedSplit.incomeTransactionId {
                    let incomeRef = db.collection("users").document(payerUid).collection("transactions").document(incomeId)
                    batch.deleteDocument(incomeRef)
                }
            }
        }
        
        // 5. Group Transaction Feed UPSERT / DELETE
        if let groupId = groupId {
            // Check for existing Group Transaction
            let existingGroupTxs = try? await db.collection("groups").document(groupId).collection("transactions")
                .whereField("originalTransactionId", isEqualTo: transactionRef.documentID)
                .getDocuments()
                
            // Deduplicate if multiple found (sanity check)
            if let docs = existingGroupTxs?.documents, docs.count > 1 {
                for i in 1..<docs.count {
                    batch.deleteDocument(docs[i].reference)
                }
            }
            
            let existingDoc = existingGroupTxs?.documents.first
            
            if updatedSplits.isEmpty {
                // CASE: No splits left -> DELETE group transaction if it exists
                if let doc = existingDoc {
                     batch.deleteDocument(doc.reference)
                }
            } else {
                // CASE: Active splits -> UPSERT
                let groupTxRef = existingDoc?.reference ?? db.collection("groups").document(groupId).collection("transactions").document()
                
                // Convert Total Amount too for the Feed Display
                var convertedTotal = finalTransaction.amount
                if sourceCurrency != targetCurrency && conversionRate > 0 {
                     convertedTotal = finalTransaction.amount / conversionRate
                }
                
                // ✅ FIX: Resolve category metadata from transaction fields for group transaction feed
                let groupCategoryName = finalTransaction.subtitle
                let groupCategoryId = finalTransaction.categoryId
                let groupIcon = finalTransaction.icon
                let groupColorHex = finalTransaction.colorHex
    
                let groupTx = FirestoreModels.GroupTransaction(
                    id: nil, // @DocumentID must be nil for writing
                    title: finalTransaction.title, // ✅ Correctly use Title ("Dinner")
                    amount: convertedTotal, // ✅ Store Converted Total
                    payerId: payerUid,
                    payerName: payerName,
                    date: finalTransaction.date,
                    type: finalTransaction.type,
                    currencyCode: targetCurrency, // ✅ Store Target Currency
                    note: finalTransaction.note, // ✅ NEW: Store Note ("Burger King")
                    categoryId: groupCategoryId, // ✅ FIX: Store category ID
                    category: groupCategoryName, // ✅ FIX: Store resolved category name
                    icon: groupIcon, // ✅ FIX: Store resolved icon
                    colorHex: groupColorHex, // ✅ FIX: Store resolved color
                    originalTransactionId: finalTransaction.id,
                    originalAmount: (sourceCurrency != targetCurrency) ? finalTransaction.amount : nil,
                    exchangeRate: (sourceCurrency != targetCurrency) ? conversionRate : nil,
                    editHistory: finalTransaction.editHistory // ✅ Sync Edit History
                )
                try batch.setData(from: groupTx, forDocument: groupTxRef)
            }
        }
        
        // 6. Delete helper (if transaction is being "deleted" logic? No, this is create/update)
        
        // 7. Commit Batch (with retry for transient network errors)
        try await withRetry {
            try await batch.commit()
        }
        return finalTransaction
    }
    
    /// `deleteSocialTransaction`, `resolveSplitRequestAction`, `declineSplitRequest`,
    /// `deleteSplitRequestAndSync`, `markSplitAsPaid`, `unmarkSplitAsPaid`,
    /// `revertLinkedSplitIfNeeded`, and `settleUp` are defined in extension files:
    /// - SocialTransactionManager+Deletion.swift
    /// - SocialTransactionManager+Splits.swift
    /// - SocialTransactionManager+Settlement.swift
}
