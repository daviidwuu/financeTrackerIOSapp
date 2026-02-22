import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

extension SocialTransactionManager {

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
        try await withRetry {
            try await batch.commit()
        }
            print("✅ Merged \(updateCount) transactions from guest \(guestId) to friend \(friend.name)")
        } else {
            // Even if no transactions, delete the guest
            try await guestRef.delete()
            print("✅ Guest \(guestId) deleted (no transactions to merge)")
        }
    }

}
