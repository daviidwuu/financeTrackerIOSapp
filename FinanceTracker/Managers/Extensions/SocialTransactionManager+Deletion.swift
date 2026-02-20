import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

extension SocialTransactionManager {

func deleteSocialTransaction(groupTransaction: FirestoreModels.GroupTransaction, groupId: String) async throws {
        let currentUserId = Auth.auth().currentUser?.uid
        
        // If this is a settlement, unmark the split as paid instead!
        if groupTransaction.type == "settlement", let requestId = groupTransaction.originalTransactionId {
            let requestRef = db.collection("split_requests").document(requestId)
            if let snapshot = try? await requestRef.getDocument(), let request = try? snapshot.data(as: FirestoreModels.SplitRequest.self) {
                try await unmarkSplitAsPaid(request: request, currentUserId: currentUserId ?? "")
            } else {
                // If request not found, just delete the orphan group transaction
                let batch = db.batch()
                if let txId = groupTransaction.id {
                     let ref = db.collection("groups").document(groupId).collection("transactions").document(txId)
                     batch.deleteDocument(ref)
                }
                try await batch.commit()
            }
            return
        }
        
        let batch = db.batch()
        
        // 1. Delete Group Transaction (Archive First)
        if let txId = groupTransaction.id {
             let ref = db.collection("groups").document(groupId).collection("transactions").document(txId)
             // Archive
             let archiveRef = db.collection("groups").document(groupId).collection("archived_transactions").document(txId)
             _ = try? batch.setData(from: groupTransaction, forDocument: archiveRef)
             
             batch.deleteDocument(ref)
        }
        
        // If no original transaction is linked (e.g. legacy settlement), we are done.
        guard let originalTxId = groupTransaction.originalTransactionId else {
            try await batch.commit()
            return
        }
        
        // 2. Delete Split Requests (Archive First)
        // If we are NOT the payer, we can only delete requests where we are involved?
        // But deleting the group transaction implies deleting the whole event.
        // Assuming user has permission (e.g. Group Admin or Payer).
        // If Payer != Current User, we can't delete Payer's transaction, but maybe we can delete requests?
        
        let requests = try await db.collection("split_requests")
            .whereField("transactionId", isEqualTo: originalTxId)
            .whereField("fromUid", isEqualTo: groupTransaction.payerId)
            .getDocuments()
            
        for doc in requests.documents {
            // Archive
            let archiveRef = db.collection("archived_split_requests").document(doc.documentID)
            let data = doc.data()
            batch.setData(data, forDocument: archiveRef)
            
            batch.deleteDocument(doc.reference)
        }
        
        // If current user is NOT the payer, we cannot modify the payer's private transactions.
        // We stop here to avoid permission errors.
        if let currentUserId = currentUserId, currentUserId != groupTransaction.payerId {
            print("⚠️ User \(currentUserId) is not the payer (\(groupTransaction.payerId)). Skipping private transaction deletion.")
            try await batch.commit()
            return
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
        } else {
            // FALLBACK: Search user's groups for Group Transaction (for orphaned transactions)
            // This handles cases where no split requests exist but a group transaction does.
            let userGroupsSnapshot = try await db.collection("groups")
                .whereField("members", arrayContains: transaction.userId)
                .getDocuments()
                
            for groupDoc in userGroupsSnapshot.documents {
                let groupTxsSnapshot = try await groupDoc.reference.collection("transactions")
                    .whereField("originalTransactionId", isEqualTo: transactionId)
                    .getDocuments()
                    
                for doc in groupTxsSnapshot.documents {
                    // Archive
                    let archiveRef = db.collection("groups").document(groupDoc.documentID).collection("archived_transactions").document(doc.documentID)
                    batch.setData(doc.data(), forDocument: archiveRef)
                    batch.deleteDocument(doc.reference)
                }
            }
        }
        
        // 3. Delete Linked Income Transactions (Reimbursements)
        // If we delete the expense, we must delete the reimbursement to avoid artificial profit.
        if let splits = transaction.splits {
            for split in splits {
                if let incomeId = split.incomeTransactionId {
                    let incomeRef = db.collection("users").document(transaction.userId).collection("transactions").document(incomeId)
                    batch.deleteDocument(incomeRef)
                }
            }
        }

        // 4. Delete the Transaction Itself (Archive First)
        let transactionRef = db.collection("users").document(transaction.userId).collection("transactions").document(transactionId)
        
        let archiveTxRef = db.collection("users").document(transaction.userId).collection("archived_transactions").document(transactionId)
        try batch.setData(from: transaction, forDocument: archiveTxRef)
        
        batch.deleteDocument(transactionRef)
        
        try await batch.commit()
    }

func deleteSplitRequestAndSync(request: FirestoreModels.SplitRequest) async throws {
        guard let requestId = request.id else { return }
        let batch = db.batch()
        let currentUserId = Auth.auth().currentUser?.uid
        
        // 1. Delete the Split Request
        let requestRef = db.collection("split_requests").document(requestId)
        batch.deleteDocument(requestRef)
        
        // 2. Update Source Transaction
        // Security Rule Check: Can only update our own transactions.
        if let currentUserId = currentUserId, currentUserId == request.fromUid {
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
        } else {
             // If we are not the Payer, we skip updating the transaction to avoid permission errors.
             // However, this leaves the Payer's transaction in an inconsistent state if we delete the request.
             // This method should ideally NOT be called if we are not the Payer.
             // Use `resolveSplitRequestAction` instead.
             print("⚠️ Warning: Non-Payer deleting request. Private transaction not updated.")
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

}
