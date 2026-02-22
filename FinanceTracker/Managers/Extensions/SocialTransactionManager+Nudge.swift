import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

extension SocialTransactionManager {

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
        try await withRetry {
            try await batch.commit()
        }
        
        // Note: Real push notification would be triggered via Cloud Functions watching this field update
        // or a separate notifications collection.
    }

    func hideSplitForUser(requestId: String, userId: String) async throws {
        let ref = db.collection("split_requests").document(requestId)
        try await ref.updateData([
            "hiddenFor": FieldValue.arrayUnion([userId])
        ])
    }

}
