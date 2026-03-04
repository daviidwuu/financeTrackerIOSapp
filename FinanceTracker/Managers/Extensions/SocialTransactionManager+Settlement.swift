import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

extension SocialTransactionManager {

    func settleUp(payerId: String, receiverId: String, groupId: String?, amount: Double, currency: String? = nil, payerName: String = "Member", receiverName: String? = nil, method: String = "Cash", note: String? = nil) async throws {
        // Payer Side (Expense)
        let payerRef = db.collection("users").document(payerId).collection("transactions").document()
        
        let displayTitle = note?.isEmpty == false ? note! : "Settled up via \(method)"
        let displayNote = note?.isEmpty == false ? note! : "Settled up via \(method)"
        
        // 1. Create a "Payment" transaction
        let paymentTransaction = FirestoreModels.TransactionModel(
            id: payerRef.documentID,
            userId: payerId,
            title: displayTitle,
            categoryId: nil, // Note: Setting up a specific system category via ID might be better long term
            amount: -amount, // Expense for payer
            date: Date(),
            type: "expense",
            createdAt: Date(),
            note: displayNote
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
             fromName: payerName, // FIX 3.2: Use actual payer name instead of "Settlement"
             toName: receiverName, // ✅ Updated from nil
             amount: amount,
             currency: currency ?? CurrencyManager.shared.mainCurrency, // FIX 1.2: Store settlement currency
             note: displayNote,
             category: "Settlement",
             icon: "arrow.turn.down.left",
             colorHex: "#34C759",
             status: .pending, // ✅ CHANGED: Pending until receiver accepts
             dependencyId: nil,
             lastNudgedAt: nil,
             originalTotalAmount: amount, // Settlement = full amount
             isSettlement: true, // ✅ NEW: Flag for settlement-specific UI
             createdAt: Date()
        )
        
        try batch.setData(from: settlementRequest, forDocument: requestRef)
        
        // Group Feed
        if let groupId = groupId {
            let groupRef = db.collection("groups").document(groupId).collection("transactions").document()
            let groupTx = FirestoreModels.GroupTransaction(
                id: nil,
                title: displayTitle,
                amount: amount,
                payerId: payerId,
                payerName: payerName, 
                receiverId: receiverId, // ✅ Store Receiver ID
                receiverName: receiverName, // ✅ Added parameter
                date: Date(),
                type: "settlement", // Special type
                currencyCode: nil,
                note: displayNote,
                originalTransactionId: payerRef.documentID, // Linked to payer transaction
                involvedUserStatuses: [receiverId: "pending"], // ✅ NEW: Track receiver's status
                editHistory: nil
            )
            try batch.setData(from: groupTx, forDocument: groupRef)
        }
        
        // ✅ REMOVED: Immediate cascade of pending splits.
        // The cascade now happens only when User B accepts the settlement
        // via acceptSettlement(), ensuring User B has a chance to verify.
        
        // FIX #18: Use retry with exponential backoff for the critical settlement commit
        try await withRetry {
            try await batch.commit()
        }
    }

    // MARK: - Settlement Acceptance / Decline
    
    /// Called by User B (receiver) when they accept a settlement.
    /// Creates an income transaction for User B, marks the settlement request as paid,
    /// then cascades a partial settle to outstanding splits between these users.
    func acceptSettlement(request: FirestoreModels.SplitRequest, currentUserId: String, currentUserName: String) async throws {
        guard let requestId = request.id else { return }
        
        let batch = db.batch()
        
        // 1. Mark the settlement request as paid
        let requestRef = db.collection("split_requests").document(requestId)
        batch.updateData([
            "status": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue,
            "lastUpdatedBy": currentUserId
        ], forDocument: requestRef)
        
        // 2. Create income transaction for User B (receiver)
        let incomeRef = db.collection("users").document(currentUserId).collection("transactions").document()
        let incomeTransaction = FirestoreModels.TransactionModel(
            id: incomeRef.documentID,
            userId: currentUserId,
            title: "Settlement from \(request.fromName ?? "Friend")",
            amount: request.amount, // Positive = income
            date: Date(),
            type: "income",
            createdAt: Date(),
            note: "Settlement from \(request.fromName ?? "Friend")",
            source: requestId
        )
        try batch.setData(from: incomeTransaction, forDocument: incomeRef)
        
        // 3. Update group feed status badge (if group settlement)
        if let groupId = request.groupId {
            let groupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                .whereField("originalTransactionId", isEqualTo: request.transactionId)
                .getDocuments()
            if let groupTxDoc = groupTxs.documents.first {
                batch.updateData([
                    "involvedUserStatuses.\(currentUserId)": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue
                ], forDocument: groupTxDoc.reference)
            }
        }
        
        // 4. Cascade: Partially settle outstanding splits (oldest first)
        // Find pending splits where receiver (creditor) has bills with payer (debtor)
        let pendingSplits = try await db.collection("split_requests")
            .whereField("fromUid", isEqualTo: currentUserId) // Receiver is the creditor
            .whereField("toUid", isEqualTo: request.fromUid) // Payer is the debtor
            .whereField("status", isEqualTo: FirestoreModels.SplitRequest.RequestStatus.pending.rawValue)
            .getDocuments()
        
        var remainingAmount = request.amount
        
        // Sort by createdAt ascending (oldest first)
        let sortedDocs = pendingSplits.documents.sorted { doc1, doc2 in
            let date1 = (doc1.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let date2 = (doc2.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            return date1 < date2
        }
        
        for doc in sortedDocs {
            guard remainingAmount > 0.01 else { break }
            
            // FIX 1.2: Only settle splits matching the settlement currency
            // FIX #9: Treat nil currency as user's main currency so old splits aren't permanently skipped
            if let settleCurrency = request.currency {
                let splitCurrency = doc.data()["currency"] as? String ?? CurrencyManager.shared.mainCurrency
                if splitCurrency != settleCurrency {
                    continue
                }
            }
            
            let splitAmount = doc.data()["amount"] as? Double ?? 0
            
            if splitAmount <= remainingAmount {
                // Full settle: mark as paid
                batch.updateData([
                    "status": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue,
                    "lastUpdatedBy": currentUserId
                ], forDocument: doc.reference)
                remainingAmount -= splitAmount
                
                // Update parent group transaction badge
                if let groupId = doc.data()["groupId"] as? String,
                   let originalTxId = doc.data()["transactionId"] as? String {
                    let groupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                        .whereField("originalTransactionId", isEqualTo: originalTxId)
                        .getDocuments()
                    if let groupTxDoc = groupTxs.documents.first {
                        batch.updateData([
                            "involvedUserStatuses.\(request.fromUid)": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue
                        ], forDocument: groupTxDoc.reference)
                    }
                }
            }
            // If splitAmount > remainingAmount, skip (partial not supported at split level)
        }
        
        try await withRetry {
            try await batch.commit()
        }
    }
    
    /// Called by User B (receiver) when they decline a settlement.
    /// Marks the settlement request as declined and updates the group feed badge.
    func declineSettlement(request: FirestoreModels.SplitRequest) async throws {
        guard let requestId = request.id else { return }
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        // 1. Mark request as declined
        let requestRef = db.collection("split_requests").document(requestId)
        batch.updateData([
            "status": FirestoreModels.SplitRequest.RequestStatus.declined.rawValue,
            "lastUpdatedBy": currentUserId
        ], forDocument: requestRef)
        
        // 2. Update group feed status badge
        if let groupId = request.groupId {
            let groupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                .whereField("originalTransactionId", isEqualTo: request.transactionId)
                .getDocuments()
            if let groupTxDoc = groupTxs.documents.first {
                batch.updateData([
                    "involvedUserStatuses.\(currentUserId)": FirestoreModels.SplitRequest.RequestStatus.declined.rawValue
                ], forDocument: groupTxDoc.reference)
            }
        }
        
        try await withRetry {
            try await batch.commit()
        }
    }

}
