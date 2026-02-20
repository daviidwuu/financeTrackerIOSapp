import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

extension SocialTransactionManager {

    func settleUp(payerId: String, receiverId: String, groupId: String?, amount: Double, currency: String? = nil, payerName: String = "Member", receiverName: String? = nil, method: String = "Cash", category: String = "Settlement", icon: String = "dollarsign.circle.fill", colorHex: String = "#34C759", note: String? = nil) async throws {
        // Payer Side (Expense)
        let payerRef = db.collection("users").document(payerId).collection("transactions").document()
        
        let displayTitle = note?.isEmpty == false ? note! : category
        let displayNote = note?.isEmpty == false ? note! : "Settled up via \(method)"
        
        // 1. Create a "Payment" transaction
        let paymentTransaction = FirestoreModels.TransactionModel(
            id: payerRef.documentID,
            userId: payerId,
            title: displayTitle,
            subtitle: category,
            amount: -amount, // Expense for payer
            date: Date(),
            type: "expense",
            createdAt: Date(),
            icon: icon,
            colorHex: colorHex,
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
             status: .paid, // Mark as PAID immediately so it triggers the Cloud Function
             dependencyId: nil,
             lastNudgedAt: nil,
             originalTotalAmount: amount, // Settlement = full amount
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
                category: category,
                icon: icon,
                colorHex: colorHex,
                originalTransactionId: payerRef.documentID, // Linked to payer transaction
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
             // FIX 1.2: Only settle splits matching the settlement currency
             if let settleCurrency = currency,
                let splitCurrency = doc.data()["currency"] as? String,
                splitCurrency != settleCurrency {
                 continue // Skip splits in different currencies
             }
             batch.updateData(["status": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue, "lastUpdatedBy": payerId], forDocument: doc.reference)
             
             // NOTE: We do NOT update the original transaction here. 
             // The Cloud Function will pick up this status change and sync it to the Creditor's transaction.
        }
        
        // FIX #18: Use retry with exponential backoff for the critical settlement commit
        try await withRetry {
            try await batch.commit()
        }
    }

}
