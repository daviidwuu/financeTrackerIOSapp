import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

extension SocialTransactionManager {

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
        
        let ref = db.collection("split_requests").document(requestId)
        try await ref.updateData([
            "status": FirestoreModels.SplitRequest.RequestStatus.declined.rawValue,
            "lastUpdatedBy": updatedBy
        ])
        
        // Update Group Feed Status
        if let groupId = request.groupId {
             let groupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                 .whereField("originalTransactionId", isEqualTo: request.transactionId)
                 .getDocuments()
                 
             if let groupTxDoc = groupTxs.documents.first {
                 try await groupTxDoc.reference.updateData([
                     "involvedUserStatuses.\(request.toUid)": FirestoreModels.SplitRequest.RequestStatus.declined.rawValue
                 ])
             }
        }
    }

func markSplitAsPaid(request: FirestoreModels.SplitRequest, currentUserId: String, currentUserName: String) async throws -> FirestoreModels.TransactionModel? {
        guard let requestId = request.id else { return nil }
        
        let creditorId = request.fromUid
        let originalTxId = request.transactionId
        
        let txRef = db.collection("users").document(creditorId).collection("transactions").document(originalTxId)
        let requestRef = db.collection("split_requests").document(requestId)
        
        let groupRef: DocumentReference?
        if let groupId = request.groupId {
             groupRef = db.collection("groups").document(groupId).collection("transactions").document()
        } else {
             groupRef = nil
        }
        
        // Pre-fetch GroupTx for the original transaction so we can update its status badge
        var groupTxRefToUpdate: DocumentReference? = nil
        if let groupId = request.groupId {
             let existingGroupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                  .whereField("originalTransactionId", isEqualTo: request.transactionId)
                  .getDocuments()
             groupTxRefToUpdate = existingGroupTxs.documents.first?.reference
        }
        
        // Perform atomic transaction to avoid race conditions and hidden encoding errors
        let generatedTx = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
                var incomeTxDict: [String: Any]? = nil
                
                // 1. Fetch transaction and securely serialize
                let txSnapshot = try transaction.getDocument(txRef)
                
                if txSnapshot.exists {
                    let txData = try txSnapshot.data(as: FirestoreModels.TransactionModel.self)
                    if var splits = txData.splits {
                        if let index = splits.firstIndex(where: { $0.requestId == requestId || (($0.friendId == request.toUid || $0.guestId == request.toUid) && !$0.isPaid) }) {
                             splits[index].isPaid = true
                             splits[index].paidDate = Date()
                             
                             if currentUserId == creditorId {
                                 let incomeRef = self.db.collection("users").document(creditorId).collection("transactions").document()
                                 let incomeTx = FirestoreModels.TransactionModel(
                                     id: incomeRef.documentID,
                                     userId: creditorId,
                                     title: "Payment received from \(request.toName ?? "User")",
                                     categoryId: txData.categoryId,
                                     amount: request.amount,
                                     date: Date(),
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
                             // Strict Write (throws on failure, aborting atomic transaction cleanly)
                             try transaction.setData(from: updatedTx, forDocument: txRef)
                        }
                    }
                }
                
                // 2. Update Request Status
                transaction.updateData([
                    "status": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue,
                    "lastUpdatedBy": currentUserId
                ], forDocument: requestRef)
                
                // Update parent Group Transaction badge status
                if let updateRef = groupTxRefToUpdate {
                     transaction.updateData([
                          "involvedUserStatuses.\(request.toUid)": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue
                     ], forDocument: updateRef)
                }
                
                // 3. Create Group Settlement Notification
                if let groupRef = groupRef {
                    let payerName = request.toName ?? "Member"
                    let receiverName = request.fromName ?? "Member"
                     
                    let groupTx = FirestoreModels.GroupTransaction(
                        id: nil,
                        title: "Settlement",
                        amount: request.amount,
                        payerId: request.toUid,
                        payerName: payerName,
                        receiverId: request.fromUid,
                        receiverName: receiverName,
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
        
        if let dict = generatedTx as? [String: Any], let tx = try? Firestore.Decoder().decode(FirestoreModels.TransactionModel.self, from: dict) {
            return tx
        }
        return nil
    }

func unmarkSplitAsPaid(request: FirestoreModels.SplitRequest, currentUserId: String) async throws {
        guard let requestId = request.id else { return }
        let batch = db.batch()
        
        // 1. Update Request Status
        let requestRef = db.collection("split_requests").document(requestId)
        batch.updateData([
            "status": FirestoreModels.SplitRequest.RequestStatus.pending.rawValue,
            "lastUpdatedBy": currentUserId
        ], forDocument: requestRef)
        
        // 1b. Update Group Feed Badge
        if let groupId = request.groupId {
             let existingGroupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                  .whereField("originalTransactionId", isEqualTo: request.transactionId)
                  .getDocuments()
             if let groupTxDoc = existingGroupTxs.documents.first {
                  batch.updateData([
                       "involvedUserStatuses.\(request.toUid)": FirestoreModels.SplitRequest.RequestStatus.pending.rawValue
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
