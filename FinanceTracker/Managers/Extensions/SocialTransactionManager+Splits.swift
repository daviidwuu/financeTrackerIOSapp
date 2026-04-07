import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

extension SocialTransactionManager {

func acceptSplitRequest(
        request: FirestoreModels.SplitRequest,
        acceptedTransaction: FirestoreModels.TransactionModel,
        currentUserId: String
    ) async throws -> FirestoreModels.TransactionModel {
        guard let requestId = request.id else {
            throw NSError(
                domain: "SocialTransactionManager",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Split request is missing an ID."]
            )
        }

        guard currentUserId == request.toUid else {
            throw NSError(
                domain: "SocialTransactionManager",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Only the receiver can accept this request."]
            )
        }

        let batch = db.batch()
        let transactionRef = acceptedTransaction.id.map {
            db.collection("users").document(currentUserId).collection("transactions").document($0)
        } ?? db.collection("users").document(currentUserId).collection("transactions").document()

        var finalTransaction = acceptedTransaction
        finalTransaction.id = transactionRef.documentID
        finalTransaction.userId = currentUserId
        finalTransaction.createdAt = Date()

        try batch.setData(from: finalTransaction, forDocument: transactionRef)

        let requestRef = db.collection("split_requests").document(requestId)
        batch.updateData([
            "status": FirestoreModels.SplitRequest.RequestStatus.accepted.rawValue,
            "lastUpdatedBy": currentUserId
        ], forDocument: requestRef)

        if let groupId = request.groupId {
            let groupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                .whereField("originalTransactionId", isEqualTo: request.transactionId)
                .getDocuments()

            if let groupTxDoc = groupTxs.documents.first {
                batch.updateData([
                    "involvedUserStatuses.\(request.toUid)": FirestoreModels.SplitRequest.RequestStatus.accepted.rawValue
                ], forDocument: groupTxDoc.reference)
            }
        }

        try await withRetry {
            try await batch.commit()
        }

        return finalTransaction
    }

func resolveSplitRequestAction(request: FirestoreModels.SplitRequest) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        if currentUserId == request.fromUid {
            // Case 1: I am the Payer/Sender -> DELETE (Cancel Request)
            try await deleteSplitRequestAndSync(request: request)
        } else {
            // Case 2: I am the Receiver -> DECLINE
            // We do not delete. We mark as declined.
            // The Cloud Function `v2_onSplitRequestUpdated` will sync this status to the Payer's transaction.
            try await declineSplitRequest(request: request)
        }
    }

private func declineSplitRequest(request: FirestoreModels.SplitRequest) async throws {
        guard let requestId = request.id else { return }
        let currentUserId = Auth.auth().currentUser?.uid
        let updatedBy = currentUserId ?? ""

        let batch = db.batch()

        let ref = db.collection("split_requests").document(requestId)
        batch.updateData([
            "status": FirestoreModels.SplitRequest.RequestStatus.declined.rawValue,
            "lastUpdatedBy": updatedBy
        ], forDocument: ref)

        // Update Group Feed Status atomically in the same batch to avoid partial state
        if let groupId = request.groupId {
            let groupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                .whereField("originalTransactionId", isEqualTo: request.transactionId)
                .getDocuments()

            if let groupTxDoc = groupTxs.documents.first {
                batch.updateData([
                    "involvedUserStatuses.\(request.toUid)": FirestoreModels.SplitRequest.RequestStatus.declined.rawValue
                ], forDocument: groupTxDoc.reference)
            }
        }

        try await withRetry {
            try await batch.commit()
        }
    }

func markSplitAsPaid(request: FirestoreModels.SplitRequest, currentUserId: String, currentUserName: String) async throws -> FirestoreModels.TransactionModel? {
        guard let requestId = request.id else { return nil }

        let creditorId = request.fromUid
        let requestRef = db.collection("split_requests").document(requestId)

        // SECURITY: Firestore rules only allow users to read/write their own private transaction
        // subcollection (users/{uid}/transactions). If the current user is the DEBTOR (toUid),
        // they do NOT have permission to read or write the creditor's transaction document.
        //
        // When the debtor marks a split as paid: we only update the split_requests status here.
        // The Cloud Function `v2_onSplitRequestUpdated` watches for 'paid' status transitions
        // and atomically updates the creditor's transaction + creates the income transaction server-side.
        //
        // When the creditor marks a split as paid (self-reporting): we run a full Firestore
        // transaction to atomically update the transaction doc and create the income entry.

        let callerIsCreditor = currentUserId == creditorId

        if callerIsCreditor {
            // Creditor path: atomic Firestore transaction covering own transaction doc, income creation,
            // split_request status, and group feed badge.
            let originalTxId = request.transactionId
            let txRef = db.collection("users").document(creditorId).collection("transactions").document(originalTxId)

            // Pre-fetch GroupTx reference for the status badge update
            var groupTxRefToUpdate: DocumentReference? = nil
            if let groupId = request.groupId {
                let existingGroupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                    .whereField("originalTransactionId", isEqualTo: request.transactionId)
                    .getDocuments()
                groupTxRefToUpdate = existingGroupTxs.documents.first?.reference
            }

            let groupFeedRef: DocumentReference? = request.groupId.map {
                db.collection("groups").document($0).collection("transactions").document()
            }

            let generatedTx = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                do {
                    var incomeTxDict: [String: Any]? = nil

                    // 1. Read + update the creditor's source transaction
                    let txSnapshot = try transaction.getDocument(txRef)
                    if txSnapshot.exists {
                        let txData = try txSnapshot.data(as: FirestoreModels.TransactionModel.self)
                        if var splits = txData.splits {
                            if let index = splits.firstIndex(where: {
                                $0.requestId == requestId ||
                                (($0.friendId == request.toUid || $0.guestId == request.toUid) && !$0.isPaid)
                            }) {
                                splits[index].isPaid = true
                                splits[index].paidDate = Date()

                                // Create income transaction idempotently.
                                // Also handles the race condition where the Cloud Function hasn't yet
                                // cleared incomeTransactionId after an unmark: if the split isn't
                                // currently paid on the server, the old ID is stale and we create fresh.
                                if splits[index].incomeTransactionId == nil || !splits[index].isPaid {
                                    let incomeRef = self.db.collection("users").document(creditorId).collection("transactions").document()
                                    // Use the original transaction's date so the income entry always
                                    // appears in the same month as the expense it settles.
                                    let incomeDate = txData.date
                                    let incomeTx = FirestoreModels.TransactionModel(
                                        id: incomeRef.documentID,
                                        userId: creditorId,
                                        title: "Payment received from \(request.toName ?? "User")",
                                        categoryId: txData.categoryId,
                                        amount: request.amount,
                                        date: incomeDate,
                                        type: "income",
                                        createdAt: Date(),
                                        note: "Payment received from \(request.toName ?? "User")",
                                        source: requestId,
                                        splits: nil
                                    )
                                    try transaction.setData(from: incomeTx, forDocument: incomeRef)
                                    splits[index].incomeTransactionId = incomeRef.documentID
                                    incomeTxDict = try? Firestore.Encoder().encode(incomeTx)
                                }

                                var updatedTx = txData
                                updatedTx.splits = splits
                                try transaction.setData(from: updatedTx, forDocument: txRef)
                            }
                        }
                    }

                    // 2. Mark split request as paid
                    transaction.updateData([
                        "status": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue,
                        "lastUpdatedBy": currentUserId
                    ], forDocument: requestRef)

                    // 3. Update group feed badge
                    if let updateRef = groupTxRefToUpdate {
                        transaction.updateData([
                            "involvedUserStatuses.\(request.toUid)": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue
                        ], forDocument: updateRef)
                    }

                    // 4. Add group settlement feed entry
                    if let groupRef = groupFeedRef {
                        let groupTx = FirestoreModels.GroupTransaction(
                            id: nil,
                            title: "Settlement",
                            amount: request.amount,
                            payerId: request.toUid,
                            payerName: request.toName ?? "Member",
                            receiverId: request.fromUid,
                            receiverName: request.fromName ?? "Member",
                            date: Date(),
                            type: "settlement",
                            currencyCode: request.currency,
                            note: request.note,
                            originalTransactionId: requestId,
                            editHistory: nil
                        )
                        try transaction.setData(from: groupTx, forDocument: groupRef)
                    }

                    return incomeTxDict
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
            }

            if let dict = generatedTx as? [String: Any],
               let tx = try? Firestore.Decoder().decode(FirestoreModels.TransactionModel.self, from: dict) {
                return tx
            }
            return nil

        } else {
            // Debtor path: only update the split_request status. The Cloud Function
            // `v2_onSplitRequestUpdated` will atomically handle the creditor's transaction
            // and income creation server-side, avoiding any cross-user write from the client.
            let batch = db.batch()

            batch.updateData([
                "status": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue,
                "lastUpdatedBy": currentUserId
            ], forDocument: requestRef)

            // Update group feed badge (group doc is not a private user collection — allowed)
            if let groupId = request.groupId {
                let existingGroupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                    .whereField("originalTransactionId", isEqualTo: request.transactionId)
                    .getDocuments()
                if let groupTxDoc = existingGroupTxs.documents.first {
                    batch.updateData([
                        "involvedUserStatuses.\(request.toUid)": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue
                    ], forDocument: groupTxDoc.reference)
                }
            }

            try await withRetry {
                try await batch.commit()
            }
            return nil
        }
    }

func unmarkSplitAsPaid(request: FirestoreModels.SplitRequest, currentUserId: String) async throws {
        guard let requestId = request.id else { return }
        let batch = db.batch()
        
        // 1. Update Request Status
        // Smart revert: guest splits go back to .pending; real user splits go back to .accepted
        // since the friend had already accepted the request before it was marked paid.
        let revertStatus: FirestoreModels.SplitRequest.RequestStatus = (request.isGuest == true) ? .pending : .accepted
        let requestRef = db.collection("split_requests").document(requestId)
        batch.updateData([
            "status": revertStatus.rawValue,
            "lastUpdatedBy": currentUserId
        ], forDocument: requestRef)

        // 1b. Update Group Feed Badge
        if let groupId = request.groupId {
             let existingGroupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                  .whereField("originalTransactionId", isEqualTo: request.transactionId)
                  .getDocuments()
             if let groupTxDoc = existingGroupTxs.documents.first {
                  batch.updateData([
                       "involvedUserStatuses.\(request.toUid)": revertStatus.rawValue
                  ], forDocument: groupTxDoc.reference)
             }
        }
        
        // 2. Transaction cleanup (income + expense deletion, isPaid revert) is handled
        //    entirely by the Cloud Function to avoid race conditions.
        
        // 3. Delete Group Transaction (Settlement)
        if let groupId = request.groupId {
            let groupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                .whereField("originalTransactionId", isEqualTo: requestId)
                .getDocuments()
            
            for doc in groupTxs.documents {
                batch.deleteDocument(doc.reference)
            }
        }
        
        try await withRetry {
            try await batch.commit()
        }
    }

func unmarkSplitAsPaid(request: FirestoreModels.SplitRequest) async throws {
        try await unmarkSplitAsPaid(request: request, currentUserId: "")
    }

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
            
            // 2. Fetch the Original Transaction to determine correct revert status
            let txRef = db.collection("users").document(currentUserId).collection("transactions").document(request.transactionId)
            let txSnapshot = try await txRef.getDocument()
            
            var newStatus = FirestoreModels.SplitRequest.RequestStatus.pending
            
            if let txData = try? txSnapshot.data(as: FirestoreModels.TransactionModel.self), var splits = txData.splits {
                if let index = splits.firstIndex(where: { $0.requestId == requestId || $0.incomeTransactionId == transaction.id }) {
                    // Smart Revert: If the split was previously accepted, revert to accepted
                    if splits[index].isAccepted {
                        newStatus = .accepted
                    }
                    
                    // 3. Update the original transaction's split array
                    splits[index].isPaid = false
                    splits[index].paidDate = nil
                    splits[index].incomeTransactionId = nil
                    splits[index].status = newStatus.rawValue // Sync status back
                    
                    var updatedTx = txData
                    updatedTx.splits = splits
                    try batch.setData(from: updatedTx, forDocument: txRef)
                }
            }
            
            // 4. Update Request Status
            batch.updateData(["status": newStatus.rawValue], forDocument: requestRef)
            
            // 5. Update Group Feed Badge
            if let groupId = request.groupId {
                 let existingGroupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                      .whereField("originalTransactionId", isEqualTo: request.transactionId)
                      .getDocuments()
                 if let groupTxDoc = existingGroupTxs.documents.first {
                      batch.updateData([
                           "involvedUserStatuses.\(request.toUid)": newStatus.rawValue
                      ], forDocument: groupTxDoc.reference)
                 }
            }
            
        try await withRetry {
            try await batch.commit()
        }
            DebugLogger.log("Reverted linked split for deleted income transaction \(transaction.id ?? "nil") to status: \(newStatus.rawValue)")
            return true
        } catch {
            DebugLogger.log("Error reverting linked split: \(error)")
            return false
        }
    }

}
