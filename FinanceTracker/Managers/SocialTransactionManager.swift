import Foundation
import FirebaseFirestore
import Combine

/// Manages complex social transaction logic: Batch writes for Transaction, SplitRequests, FriendRequests, and GroupInvitations.
class SocialTransactionManager: ObservableObject {
    static let shared = SocialTransactionManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
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
        
        // 2. Process Splits & Requests
        let updatedSplits = finalTransaction.splits ?? []
        
        // --- 2a. Determine Currency Logic ---
        let mainCurrency = CurrencyManager.shared.mainCurrency
        let travelCurrency = CurrencyManager.shared.travelCurrency
        let isTravelMode = CurrencyManager.shared.isTravelModeEnabled
        
        // Target Currency: The currency the GROUP uses (Default or Main)
        var targetCurrency = mainCurrency
        if let groupId = groupId, let group = groupCache.first(where: { $0.id == groupId }), let groupCurrency = group.defaultCurrency {
            targetCurrency = groupCurrency
        }
        
        // Source Currency: The currency of the TRANSACTION
        // If transaction has specific currency, use it. Otherwise rely on Travel Mode state.
        let sourceCurrency = finalTransaction.currencyCode ?? (isTravelMode ? travelCurrency : mainCurrency)
        
        // Conversion Rate: Source -> Target
        var conversionRate: Double = 1.0
        if sourceCurrency != targetCurrency {
            if sourceCurrency == travelCurrency && targetCurrency == mainCurrency {
                  if let txRate = finalTransaction.exchangeRate {
                      conversionRate = txRate
                  } else {
                      conversionRate = CurrencyManager.shared.exchangeRate
                  }
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
            
            if let groupId = groupId {
                if let group = groupCache.first(where: { $0.id == groupId }) {
                    if !group.members.contains(friendUid) {
                        // Check if invite already exists? 
                        // For simplicity, we just create a request that might be "blocked_by_group" if we enforced it,
                        // but here we just create a split request.
                        // Ideally we would create an invitation here.
                        // check if invitation exists logic would stay here...
                        // Skipping complex invitation logic to fix build error first, relying on basic split request.
                    }
                }
            }
            
            // --- Step C: Create/Update Split Request ---
            let requestRef: DocumentReference
            
            // Look for a matching document in our fetched list
            if let index = existingRequestsDocs.firstIndex(where: { doc in
                let docToUid = (doc.get("toUid") as? String) ?? (doc.data()["toUid"] as? String)
                return docToUid == friendUid
            }) {
                // FOUND: Reuse this document
                let existingDoc = existingRequestsDocs[index]
                requestRef = existingDoc.reference
                
                // Remove from list so we don't delete it later
                existingRequestsDocs.remove(at: index)
                
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
                status: requestStatus,
                dependencyId: dependencyId,
                lastNudgedAt: nil,
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
                for i in 0..<localSplits.count {
                    let localSplit = localSplits[i]
                    // Find corresponding remote split by ID (or friendId for legacy)
                    // Note: 'remoteSplits' is from the outer scope
                    if let remoteSplit = remoteSplits.first(where: { $0.id == localSplit.id || ($0.friendId == localSplit.friendId && $0.amount == localSplit.amount) }) {
                        
                        // Rule: If remote is PAID, local MUST respect it
                        if remoteSplit.isPaid && !localSplit.isPaid {
                            print("🔍 Safety Merge: Preserving PAID status for \(localSplit.name) from remote.")
                            localSplits[i].isPaid = true
                            localSplits[i].paidDate = remoteSplit.paidDate
                            localSplits[i].incomeTransactionId = remoteSplit.incomeTransactionId
                        }
                        
                        // Rule: If remote has a status (e.g. Declined), preserve it if local has none or is pending
                        if let remoteStatus = remoteSplit.status {
                             if localSplit.status == nil || localSplit.status == "pending" {
                                 print("🔍 Safety Merge: Preserving Status '\(remoteStatus)' for \(localSplit.name) from remote.")
                                 localSplits[i].status = remoteStatus
                             }
                        }
                    }
                }
                finalTransaction.splits = localSplits
            }
        }
        }
        // -------------------------------------------

        try batch.setData(from: finalTransaction, forDocument: transactionRef)
        
        // 4. Cleanup Removed Splits (Any docs left in existingRequestsDocs are orphans)
        for doc in existingRequestsDocs {
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
                    category: finalTransaction.subtitle, // ✅ NEW: Store Category ("Food & Dining")
                    icon: finalTransaction.icon, // ✅ NEW
                    colorHex: finalTransaction.colorHex, // ✅ NEW
                    originalTransactionId: finalTransaction.id,
                    editHistory: finalTransaction.editHistory // ✅ Sync Edit History
                )
                try batch.setData(from: groupTx, forDocument: groupTxRef)
            }
        }
        
        // 6. Delete helper (if transaction is being "deleted" logic? No, this is create/update)
        
        // 7. Commit Batch
        try await batch.commit()
        return finalTransaction
    }
    
    /// Deletes a social transaction and its associated splits/group feed items.
    func deleteSocialTransaction(groupTransaction: FirestoreModels.GroupTransaction, groupId: String) async throws {
        guard let originalTxId = groupTransaction.originalTransactionId else { return }
        
        let batch = db.batch()
        
        // 1. Delete Group Transaction (Archive First)
        if let txId = groupTransaction.id {
             let ref = db.collection("groups").document(groupId).collection("transactions").document(txId)
             // Archive
             let archiveRef = db.collection("groups").document(groupId).collection("archived_transactions").document(txId)
             _ = try? batch.setData(from: groupTransaction, forDocument: archiveRef)
             
             batch.deleteDocument(ref)
        }
        
        // 2. Delete Split Requests (Archive First)
        let requests = try await db.collection("split_requests")
            .whereField("transactionId", isEqualTo: originalTxId)
            .whereField("fromUid", isEqualTo: groupTransaction.payerId)
            .getDocuments()
            
        // 2b. If no requests found with fromUid, try finding by toUid if we are deleting someone else's request? 
        // But for deleting the whole transaction, we usually only do it if we are the payer.
        // If the query returns empty, we might be missing requests where we are the receiver?
        // But the split requests associated with a group transaction are usually created by the payer.
        
        for doc in requests.documents {
            // Archive
            let archiveRef = db.collection("archived_split_requests").document(doc.documentID)
            let data = doc.data()
            batch.setData(data, forDocument: archiveRef)
            
            batch.deleteDocument(doc.reference)
        }
        
        // 3. Delete income transactions from paid splits
        let payerId = groupTransaction.payerId
        let userTxRef = db.collection("users").document(payerId).collection("transactions").document(originalTxId)
        
        do {
            let txSnapshot = try await userTxRef.getDocument()
            if let txData = try? txSnapshot.data(as: FirestoreModels.TransactionModel.self), let splits = txData.splits {
                for split in splits {
                    if let incomeId = split.incomeTransactionId {
                        let incomeRef = db.collection("users").document(payerId).collection("transactions").document(incomeId)
                        batch.deleteDocument(incomeRef)
                    }
                }
            }
        } catch {
            print("DEBUG: Error fetching original transaction for income cleanup: \(error)")
        }
        
        // 4. Delete Original User Transaction (Archive First)
        let archiveTxRef = db.collection("users").document(payerId).collection("archived_transactions").document(originalTxId)
        do {
            if let txData = try? await userTxRef.getDocument().data(as: FirestoreModels.TransactionModel.self) {
                 try batch.setData(from: txData, forDocument: archiveTxRef)
            }
        } catch {}
        
        batch.deleteDocument(userTxRef)
        
        try await batch.commit()
    }

    /// Deletes social artifacts (SplitRequests, GroupTransactions) associated with a personal transaction.
    /// This is used when deleting a transaction from the personal list.
    func deleteSocialTransaction(transaction: FirestoreModels.TransactionModel) async throws {
        guard let transactionId = transaction.id else { return }
        
        let batch = db.batch()
        
        // 1. Find and Delete Split Requests (Archive)
        // We also need to find the groupId from these requests to delete the GroupTransaction
        let requestsSnapshot = try await db.collection("split_requests")
            .whereField("transactionId", isEqualTo: transactionId)
            .whereField("fromUid", isEqualTo: transaction.userId)
            .getDocuments()
            
        var groupId: String? = nil
        
        for doc in requestsSnapshot.documents {
            // Try to get groupId from the request
            if groupId == nil, let gid = doc.data()["groupId"] as? String {
                groupId = gid
            }
            // Archive
            let archiveRef = db.collection("archived_split_requests").document(doc.documentID)
            batch.setData(doc.data(), forDocument: archiveRef)
            
            batch.deleteDocument(doc.reference)
        }
        
        // 2. Delete Group Transaction (if we found a groupId) (Archive)
        if let groupId = groupId {
            let groupTxsSnapshot = try await db.collection("groups").document(groupId).collection("transactions")
                .whereField("originalTransactionId", isEqualTo: transactionId)
                .getDocuments()
                
            for doc in groupTxsSnapshot.documents {
                // Archive
                let archiveRef = db.collection("groups").document(groupId).collection("archived_transactions").document(doc.documentID)
                batch.setData(doc.data(), forDocument: archiveRef)
                
                batch.deleteDocument(doc.reference)
            }
        }
        
        try await batch.commit()
    }
    // deleted extra brace

    
    /// Deletes a single split request and updates the source transaction (removing the split).
    /// If no splits remain, the source transaction remains as a personal expense.
    func deleteSplitRequestAndSync(request: FirestoreModels.SplitRequest) async throws {
        guard let requestId = request.id else { return }
        let batch = db.batch()
        
        // 1. Delete the Split Request
        let requestRef = db.collection("split_requests").document(requestId)
        batch.deleteDocument(requestRef)
        
        // 2. Update Source Transaction
        let sourceTxRef = db.collection("users").document(request.fromUid).collection("transactions").document(request.transactionId)
        
        do {
            let snapshot = try await sourceTxRef.getDocument()
            if let txData = try? snapshot.data(as: FirestoreModels.TransactionModel.self), var splits = txData.splits {
                
                // Remove the split linked to this request
                if let index = splits.firstIndex(where: { $0.requestId == requestId }) {
                    // Remove split locally
                    splits.remove(at: index)
                }
                var updatedTx = txData
                updatedTx.splits = splits.isEmpty ? nil : splits
                try batch.setData(from: updatedTx, forDocument: sourceTxRef)
                
                // 3b. If no splits remain on source, remove group feed entry (Cascade)
                if splits.isEmpty, let groupId = request.groupId {
                    let groupTxs = try await db.collection("groups").document(groupId)
                        .collection("transactions")
                        .whereField("originalTransactionId", isEqualTo: request.transactionId)
                        .getDocuments()
                    
                    for doc in groupTxs.documents {
                        batch.deleteDocument(doc.reference)
                    }
                }
            }
        } catch {
            print("DEBUG: Error syncing delete of split request: \(error)")
            // We continue, as deleting the request is the primary action
        }
        
        // 3. Delete from Group Feed if applicable
        // This is tricky because the Group Transaction represents the WHOLE event, not just one split.
        // Usually we don't delete the group transaction unless all splits are gone or the user deletes the event.
        // For now, removing the split request is enough for "Independent Split Deletion".
        // The Group Transaction might still show the total amount. 
        // Ideally, we might want to update the Group Transaction amount if it was a "split by amounts".
        // But for "Split equally", the total was the total.
        
        try await batch.commit()
    }

    /// Marks a split as paid, updates the original transaction (reimbursement), and posts a group feed item.
    func markSplitAsPaid(request: FirestoreModels.SplitRequest, currentUserId: String, currentUserName: String) async throws {
        guard let requestId = request.id else { return }
        
        let batch = db.batch()
        
        // 1. Update Request Status to .paid
        let requestRef = db.collection("split_requests").document(requestId)
        batch.updateData(["status": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue], forDocument: requestRef)
        
        // 2. Sync with Original Transaction (Creditor's Side)
        let creditorId = request.fromUid
        let originalTxId = request.transactionId
        
        // Only attempt to sync if we are the creditor
        if currentUserId == creditorId {
            let txRef = db.collection("users").document(creditorId).collection("transactions").document(originalTxId)
            do {
                let txSnapshot = try await txRef.getDocument()
                if let txData = try? txSnapshot.data(as: FirestoreModels.TransactionModel.self), var splits = txData.splits {
                    
                    // Find split for this debtor
                    if let index = splits.firstIndex(where: { $0.requestId == requestId || ($0.friendId == request.toUid && !$0.isPaid) }) {
                         splits[index].isPaid = true
                         splits[index].paidDate = Date()
                     
                         // Create Reimbursement (Income) Transaction
                         // Name logic: If checking specific friend, use their name.
                         let payerName = request.toName ?? "Friend"
                         
                         let originalCategory = txData.subtitle ?? "Reimbursement"
                         
                         let incomeRef = db.collection("users").document(creditorId).collection("transactions").document()
                         
                         let incomeTx = FirestoreModels.TransactionModel(
                             id: incomeRef.documentID,
                             userId: creditorId,
                             title: "Payment Received", 
                             subtitle: originalCategory, 
                             amount: request.amount,
                             date: Date(),
                             type: "income",
                             createdAt: Date(),
                             icon: txData.icon, 
                             colorHex: "#34C759", // Green
                             note: "Payment from \(payerName) for \(request.note ?? "Split")",
                             source: requestId // Link back
                         )
                         try batch.setData(from: incomeTx, forDocument: incomeRef)
                         
                         splits[index].incomeTransactionId = incomeRef.documentID
                         
                         var updatedTx = txData
                         updatedTx.splits = splits
                         try batch.setData(from: updatedTx, forDocument: txRef)
                    }
                }
            } catch {
                print("DEBUG: Error fetching/updating transaction: \(error)")
            }
        }
        

        
        try await batch.commit()
    }
    
    /// Reverts a paid split to pending
    func unmarkSplitAsPaid(request: FirestoreModels.SplitRequest, currentUserId: String) async throws {
        guard let requestId = request.id else { return }
        let batch = db.batch()
        
        // 1. Update Request
        let requestRef = db.collection("split_requests").document(requestId)
        batch.updateData(["status": FirestoreModels.SplitRequest.RequestStatus.pending.rawValue], forDocument: requestRef)
        
        // 2. Revert Original Transaction Sync (If Creditor)
        if currentUserId == request.fromUid {
            let txRef = db.collection("users").document(currentUserId).collection("transactions").document(request.transactionId)
            do {
                let txSnapshot = try await txRef.getDocument()
                if let txData = try? txSnapshot.data(as: FirestoreModels.TransactionModel.self), var splits = txData.splits {
                    
                    // Find split
                    if let index = splits.firstIndex(where: { $0.requestId == requestId }) {
                         splits[index].isPaid = false
                         splits[index].paidDate = nil
                         
                         // Delete Income Transaction if linked
                         if let incomeId = splits[index].incomeTransactionId {
                             let incomeRef = db.collection("users").document(currentUserId).collection("transactions").document(incomeId)
                             batch.deleteDocument(incomeRef)
                             splits[index].incomeTransactionId = nil
                         }
                         
                         var updatedTx = txData
                         updatedTx.splits = splits
                         try batch.setData(from: updatedTx, forDocument: txRef)
                    }
                }
            } catch {
                print("DEBUG: Error unmarking split in transaction: \(error)")
            }
        }
        
        try await batch.commit()
    }
    
    // Legacy support or helper
    func unmarkSplitAsPaid(request: FirestoreModels.SplitRequest) async throws {
        try await unmarkSplitAsPaid(request: request, currentUserId: "")
    }
    
    /// Reverts a linked split when its "Payment Received" income transaction is deleted.
    /// Returns true if a linked split was found and reverted.
    func revertLinkedSplitIfNeeded(transaction: FirestoreModels.TransactionModel, currentUserId: String) async -> Bool {
        // Only income transactions with a source (requestId) are relevant
        guard transaction.type == "income",
              let requestId = transaction.source,
              !requestId.isEmpty else {
            return false
        }
        
        do {
            // 1. Fetch the SplitRequest
            let requestRef = db.collection("split_requests").document(requestId)
            let snapshot = try await requestRef.getDocument()
            guard let request = try? snapshot.data(as: FirestoreModels.SplitRequest.self) else {
                return false
            }
            
            // Only revert if currently paid
            guard request.status == .paid else { return false }
            
            let batch = db.batch()
            
            // 2. Revert Request Status to pending
            batch.updateData(["status": FirestoreModels.SplitRequest.RequestStatus.pending.rawValue], forDocument: requestRef)
            
            // 3. Update the original transaction's split array
            let txRef = db.collection("users").document(currentUserId).collection("transactions").document(request.transactionId)
            let txSnapshot = try await txRef.getDocument()
            if let txData = try? txSnapshot.data(as: FirestoreModels.TransactionModel.self), var splits = txData.splits {
                if let index = splits.firstIndex(where: { $0.requestId == requestId || $0.incomeTransactionId == transaction.id }) {
                    splits[index].isPaid = false
                    splits[index].paidDate = nil
                    splits[index].incomeTransactionId = nil
                    
                    var updatedTx = txData
                    updatedTx.splits = splits
                    try batch.setData(from: updatedTx, forDocument: txRef)
                }
            }
            
            try await batch.commit()
            print("DEBUG: Reverted linked split for deleted income transaction \(transaction.id ?? "nil")")
            return true
        } catch {
            print("DEBUG: Error reverting linked split: \(error)")
            return false
        }
    }

    /// Merges a Guest's history into a newly added Friend
    func mergeGuestToFriend(guestId: String, friend: FirestoreModels.Friend, currentUserId: String) async throws {
        // 1. Fetch all transactions for the current user (Payer)
        // We need to find transactions where we split with this guest.
        // Since we can't query sub-fields of array easily without index, we might need to scan.
        // Or if we have a lot, this is expensive. But for now, client-side scan is acceptable for MVP.
        
        let snapshot = try await db.collection("users").document(currentUserId).collection("transactions")
            .getDocuments()
            
        let batch = db.batch()
        var updateCount = 0
        
        for doc in snapshot.documents {
            if let tx = try? doc.data(as: FirestoreModels.TransactionModel.self), var splits = tx.splits {
                var needsUpdate = false
                
                for i in 0..<splits.count {
                    if splits[i].guestId == guestId {
                        // Found match! Update to Friend
                        splits[i].guestId = nil
                        splits[i].isGuest = false
                        splits[i].friendId = friend.id
                        splits[i].name = friend.name
                        splits[i].username = friend.username
                        needsUpdate = true
                    }
                }
                
                if needsUpdate {
                    // Update the transaction
                    var updatedTx = tx
                    updatedTx.splits = splits
                    try batch.setData(from: updatedTx, forDocument: doc.reference)
                    updateCount += 1
                }
            }
        }
        
        // 2. Delete the Guest
        let guestRef = db.collection("users").document(currentUserId).collection("guests").document(guestId)
        batch.deleteDocument(guestRef)
        
        if updateCount > 0 {
            try await batch.commit()
            print("✅ Merged \(updateCount) transactions from guest \(guestId) to friend \(friend.name)")
        } else {
            // Even if no transactions, delete the guest
            try await guestRef.delete()
            print("✅ Guest \(guestId) deleted (no transactions to merge)")
        }
    }

    /// Settles up a debt between two users
    func settleUp(payerId: String, receiverId: String, groupId: String?, amount: Double, payerName: String = "Member", receiverName: String? = nil, method: String = "Cash") async throws {
        // Payer Side (Expense)
        let payerRef = db.collection("users").document(payerId).collection("transactions").document()
        
        // 1. Create a "Payment" transaction
        let paymentTransaction = FirestoreModels.TransactionModel(
            id: payerRef.documentID,
            userId: payerId,
            title: "Payment to \(method)",
            subtitle: "Settle Up",
            amount: -amount, // Expense for payer
            date: Date(),
            type: "expense",
            createdAt: Date(),
            icon: "dollarsign.circle.fill", // Updated icon
            colorHex: "#34C759", // Green
            note: "Settled up via \(method)"
        )
        
        let batch = db.batch()
        
        try batch.setData(from: paymentTransaction, forDocument: payerRef)
        
        // Receiver Side (Income)
        // CRITICAL FIX: Do NOT write to receiver's transaction collection directly (Security Rules Violation).
        // Instead, we rely on the Cloud Function `v2_onSplitRequestUpdated` to detect the 'paid' status
        // and create the "Payment Received" transaction for the receiver securely.
        
        // 3. Counter-Request (Settlement)
        // Settlement Request acts as a Credit to offset the Debt.
        // It is FROM Payer TO Reciever, status .paid immediately.
        
        let requestRef = db.collection("split_requests").document()
        let settlementRequest = FirestoreModels.SplitRequest(
             id: nil,
             transactionId: payerRef.documentID,
             groupId: groupId,
             fromUid: payerId,
             toUid: receiverId,
             fromName: "Settlement",
             toName: receiverName, // ✅ Updated from nil
             amount: amount,
             currency: nil,
             note: "Settled via \(method)",
             status: .paid, // Mark as PAID immediately so it triggers the Cloud Function
             dependencyId: nil,
             lastNudgedAt: nil,
             createdAt: Date()
        )
        
        try batch.setData(from: settlementRequest, forDocument: requestRef)
        
        // Group Feed
        if let groupId = groupId {
            let groupRef = db.collection("groups").document(groupId).collection("transactions").document()
            let groupTx = FirestoreModels.GroupTransaction(
                id: nil,
                title: "Settlement: \(method)",
                amount: amount,
                payerId: payerId,
                payerName: payerName, 
                receiverName: receiverName, // ✅ Added parameter
                date: Date(),
                type: "settlement", // Special type
                currencyCode: nil,
                note: nil,
                category: "Settlement",
                icon: "dollarsign.circle.fill", // Updated icon
                colorHex: "#34C759",
                originalTransactionId: nil,
                editHistory: nil
            )
            try batch.setData(from: groupTx, forDocument: groupRef)
        }
        
        // 4. Mark existing pending splits between these users as paid
        // Find splits where the receiver (creditor) split bills with the payer (debtor)
        let pendingSplits = try await db.collection("split_requests")
            .whereField("fromUid", isEqualTo: receiverId)
            .whereField("toUid", isEqualTo: payerId)
            .whereField("status", isEqualTo: FirestoreModels.SplitRequest.RequestStatus.pending.rawValue)
            .getDocuments()
        
        for doc in pendingSplits.documents {
             // Mark the split request as paid
             // This update is allowed by security rules (as 'toUid' == me)
             batch.updateData(["status": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue], forDocument: doc.reference)
             
             // NOTE: We do NOT update the original transaction here. 
             // The Cloud Function will pick up this status change and sync it to the Creditor's transaction.
        }
        
        try await batch.commit()
    }

    /// Adds new members to a group
    func addMembersToGroup(groupId: String, newMembers: [(id: String, name: String)]) async throws {
        let groupRef = db.collection("groups").document(groupId)
        
        let newIds = newMembers.map { $0.id }
        let currentUserId = AppState.shared.currentUserId // Assuming this is available
        
        var updateData: [String: Any] = [
            "members": FieldValue.arrayUnion(newIds),
            "lastUpdatedBy": currentUserId, // ✅ NEW: Track who added them for notifications
            "updatedAt": Date()
        ]
        
        for member in newMembers {
            updateData["memberNames.\(member.id)"] = member.name
        }
        
        try await groupRef.updateData(updateData)
    }

    /// Sends a nudge notification to a friend for unpaid debts
    func sendNudge(to friendId: String, currentUserId: String) async throws {
        // 1. Find pending requests from current user to friend
        let snapshot = try await db.collection("split_requests")
            .whereField("fromUid", isEqualTo: currentUserId)
            .whereField("toUid", isEqualTo: friendId)
            .whereField("status", isEqualTo: FirestoreModels.SplitRequest.RequestStatus.pending.rawValue)
            .getDocuments()
            
        let batch = db.batch()
        let now = Date()
        
        // 2. Update lastNudgedAt timestamp
        for doc in snapshot.documents {
            batch.updateData(["lastNudgedAt": now], forDocument: doc.reference)
        }
        
        // 3. Commit update
        try await batch.commit()
        
        // Note: Real push notification would be triggered via Cloud Functions watching this field update
        // or a separate notifications collection.
    }
}
