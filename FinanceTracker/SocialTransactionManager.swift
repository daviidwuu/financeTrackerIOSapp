import Foundation
import FirebaseFirestore
import Combine

/// Manages complex social transaction logic: Batch writes for Transaction, SplitRequests, FriendRequests, and GroupInvitations.
class SocialTransactionManager: ObservableObject {
    static let shared = SocialTransactionManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Creates a social transaction with all necessary dependent documents in a single atomic batch.
    /// - Parameters:
    ///   - transaction: The transaction to save (transaction.splits should be populated).
    ///   - splits: The list of splits (redundant if in transaction, but passed for clarity/processing).
    ///   - payerUid: The ID of the user paying (usually current user).
    ///   - groupId: Optional ID of the group this transaction belongs to.
    ///   - friendCache: Local cache of friends to avoid redundant reads.
    ///   - groupCache: Local cache of groups to check membership.
    func createSocialTransaction(
        transaction: FirestoreModels.Transaction,
        payerUid: String,
        payerName: String,
        groupId: String?,
        friendCache: [FirestoreModels.Friend],
        groupCache: [FirestoreModels.Group]
    ) async throws {
        
        print("🔍 createSocialTransaction called with payerName: '\(payerName)', payerUid: '\(payerUid)'")
        
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
        
        // 1.5. Cleanup: Delete ANY existing split requests for this transaction (Full Refresh)
        // This ensures un-splitting (removing a friend) actually removes the request.
        let existingRequests = try? await db.collection("split_requests")
            .whereField("transactionId", isEqualTo: transactionRef.documentID)
            .getDocuments()
            
        for doc in existingRequests?.documents ?? [] {
            batch.deleteDocument(doc.reference)
        }
        
        // 2. Process Splits & Requests
        // Ensure we continue to commit batch even if splits are empty (to commit deletions)
        var updatedSplits = finalTransaction.splits ?? []
        
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
        // We only support converting Travel -> Main if Source is Travel and Target is Main
        // If complex (e.g. JPY -> EUR), we might need robust cross-rates.
        // For now, assume User's Main Currency == Group's Main Currency for simplicity, or just use stored rate.
        var conversionRate: Double = 1.0
        if sourceCurrency != targetCurrency {
            if sourceCurrency == travelCurrency && targetCurrency == mainCurrency {
                 // Rate is 1 Main = X Travel. So Amount / X = Main.
                 // We inverted this in manager: convertToMain divides by rate.
                 // Let's use the helper but we need to trust the current rate or the one in transaction.
                 if let txRate = finalTransaction.exchangeRate {
                     conversionRate = txRate
                 } else {
                     conversionRate = CurrencyManager.shared.exchangeRate
                 }
            } else {
                 // TODO: Handle other Cross-Currency cases (e.g. Group is USD, User is SGD, paying in JPY)
                 // Fallback: 1.0
            }
        }
        
        for (index, split) in updatedSplits.enumerated() {
            // Skip self and guests (guests don't get requests)
            if split.friendId == payerUid { continue }
            if split.isGuest {
                // Guests don't get requests, but we should probably track their debt in the Group Transaction or Guest Record?
                // For now, we only handle Requests.
                continue
            }
            
            guard let friendUid = split.friendId else { continue }
            
            // --- Step A: Friend Request Check (Simplified) ---
            
            // --- Step B: Group Invitation Logic ---
            var dependencyId: String? = nil
            var requestStatus: FirestoreModels.SplitRequest.RequestStatus = .pending
            
            if let groupId = groupId {
                if let group = groupCache.first(where: { $0.id == groupId }) {
                    if !group.members.contains(friendUid) {
                        // Create Invitation
                        let inviteRef = db.collection("group_invitations").document()
                        let invite = FirestoreModels.GroupInvitation(
                            id: nil,
                            groupId: groupId,
                            groupName: group.name,
                            fromUid: payerUid,
                            toUid: friendUid,
                            status: "pending",
                            dependencyId: nil,
                            createdAt: Date()
                        )
                        try batch.setData(from: invite, forDocument: inviteRef)
                        
                        dependencyId = inviteRef.documentID
                        requestStatus = .blocked_by_group
                    }
                }
            }
            
            // --- Step C: Convert Amount ---
            let originalSplitAmount = split.amount
            var finalSplitAmount = originalSplitAmount
            
            if sourceCurrency != targetCurrency {
                // Convert!
                if sourceCurrency == travelCurrency && targetCurrency == mainCurrency {
                    // Logic: Amount / Rate
                    // If Rate is 0, avoid div by zero
                    if conversionRate > 0 {
                        finalSplitAmount = originalSplitAmount / conversionRate
                    }
                }
            }
            
            // --- Step D: Split Request Creation ---
            let requestRef = db.collection("split_requests").document()
            
            let splitRequest = FirestoreModels.SplitRequest(
                id: nil,
                transactionId: transactionRef.documentID,
                groupId: groupId,
                fromUid: payerUid,
                toUid: friendUid,
                fromName: payerName,
                amount: finalSplitAmount, // ✅ Use Converted Amount
                currency: targetCurrency, // ✅ Use Target Currency (Group/Main)
                note: (transaction.note?.isEmpty == false ? transaction.note : transaction.title),
                status: requestStatus,
                dependencyId: dependencyId,
                lastNudgedAt: nil,
                createdAt: Date()
            )
            
            try batch.setData(from: splitRequest, forDocument: requestRef)
            
            // Link Request ID back to Split
            updatedSplits[index].requestId = requestRef.documentID
        }
        
        // 3. Save Transaction with linked IDs
        finalTransaction.splits = updatedSplits
        // Ensure Transaction stores the Source details
        if finalTransaction.currencyCode == nil { finalTransaction.currencyCode = sourceCurrency }
        if finalTransaction.exchangeRate == nil && sourceCurrency != mainCurrency { finalTransaction.exchangeRate = conversionRate }
        
        try batch.setData(from: finalTransaction, forDocument: transactionRef)
        
        // 4. [NEW] Group Transaction Feed
        if let groupId = groupId {
            // Write a simplified record to groups/{groupId}/transactions
            let groupTxRef = db.collection("groups").document(groupId).collection("transactions").document()
            
            // Convert Total Amount too for the Feed Display
            var convertedTotal = finalTransaction.amount
            if sourceCurrency != targetCurrency && conversionRate > 0 {
                 convertedTotal = finalTransaction.amount / conversionRate
            }

            let groupTx = FirestoreModels.GroupTransaction(
                id: nil,
                title: (finalTransaction.note?.isEmpty == false ? finalTransaction.note! : finalTransaction.title), 
                amount: convertedTotal, // ✅ Store Converted Total
                payerId: payerUid,
                payerName: payerName, 
                date: finalTransaction.date,
                type: finalTransaction.type,
                currencyCode: targetCurrency, // ✅ Store Target Currency
                originalTransactionId: finalTransaction.id 
            )
            try batch.setData(from: groupTx, forDocument: groupTxRef)
        }
        
        // 5. Commit Batch
        try await batch.commit()
    }
}
