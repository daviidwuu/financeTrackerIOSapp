import Foundation
import FirebaseFirestore
import Combine

class GroupRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var groups: [FirestoreModels.Group] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    
    private var userId: String?
    private var listener: ListenerRegistration?
    
    func startListening(userId: String) {
        self.userId = userId
        // Only show loading if we don't have any data yet (Stale-While-Revalidate)
        if groups.isEmpty {
            self.isLoading = true
        }
        self.errorMessage = nil
        
        // v2.1: Query Root Collection where user is a member
        listener = db.collection("groups")
            .whereField("members", arrayContains: userId)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false // Loading complete
                
                if let error = error {
                    self.errorMessage = "Error fetching groups: \(error.localizedDescription)"
                    DebugLogger.log("Error fetching groups: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No groups found."
                    return
                }
                
                self.errorMessage = nil
                self.groups = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.Group.self)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
        groups = []
    }
    
    /// Create a new shared group (Wiki-style)
    func addGroup(_ group: FirestoreModels.Group) async throws -> String {
        guard let userId = userId else { throw NSError(domain: "GroupRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]) }
        
        // v2.1: Root Collection
        let ref = db.collection("groups").document()
        
        var newGroup = group
        newGroup.id = ref.documentID
        newGroup.createdBy = userId
        newGroup.createdAt = Date()
        newGroup.updatedAt = Date()
        newGroup.normalizedName = group.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Ensure creator is a member
        if !newGroup.members.contains(userId) {
            newGroup.members.append(userId)
        }
        
        // We do NOT set 'lastUpdatedBy' here because for creation, the trigger uses 'createdBy'
        // But to be consistent with updates:
        var data = try Firestore.Encoder().encode(newGroup)
        data["lastUpdatedBy"] = userId
        
        try await ref.setData(data)
        return ref.documentID
    }
    
    func deleteGroup(groupId: String) async throws {
        // v2.1: Only creator can delete via Security Rules
        try await db.collection("groups").document(groupId).delete()
    }
    
    func leaveGroup(groupId: String, userId: String) async throws {
        let groupRef = db.collection("groups").document(groupId)
        
        // Atomically remove user from members array
        try await groupRef.updateData([
            "members": FieldValue.arrayRemove([userId])
        ])
        
        // Optional: Check if group is empty and delete it?
        // This is better handled by a Cloud Function trigger to clean up abandoned groups.
        // Client-side cleanup is risky if the user just loses connection.
    }
    
    func updateGroup(_ group: FirestoreModels.Group) async throws {
        guard let groupId = group.id else { return }
        
        var updatedGroup = group
        updatedGroup.updatedAt = Date()
        updatedGroup.normalizedName = group.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        try db.collection("groups").document(groupId).setData(from: updatedGroup, merge: true)
    }
    
    /// Synchronous Cache Lookup
    func isMember(groupId: String, uid: String) -> Bool {
        guard let group = groups.first(where: { $0.id == groupId }) else { return false }
        return group.members.contains(uid)
    }
    
    /// Add multiple members to a group
    func addMembersToGroup(groupId: String, newMembers: [(id: String, name: String)]) async throws {
        let groupRef = db.collection("groups").document(groupId)
        
        let newMemberIds = newMembers.map { $0.id }
        var newMemberNames: [String: String] = [:]
        for member in newMembers {
            newMemberNames[member.id] = member.name
        }
        
        // Atomically add to members array and merge names map
        // Note: FieldValue.arrayUnion only works for arrays. For maps, we need SetOptions.merge
        // But we can't do both easily in one atomic update call if one is a field value and other is a map merge on a specific field without dot notation?
        // Actually, we can update "memberNames.uid" using dot notation.
        
        var updateData: [String: Any] = [
            "members": FieldValue.arrayUnion(newMemberIds),
            "updatedAt": Date()
        ]
        
        // Add names to denormalized map
        for (uid, name) in newMemberNames {
            updateData["memberNames.\(uid)"] = name
        }
        
        try await groupRef.updateData(updateData)
    }
}
