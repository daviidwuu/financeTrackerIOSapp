import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

extension SocialTransactionManager {

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

}
