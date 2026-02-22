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

    /// Requests group deletion (Soft Delete)
    func requestGroupDeletion(group: FirestoreModels.Group) async throws {
        guard let groupId = group.id else { return }
        
        // Initialize member actions map
        var initialActions: [String: String] = [:]
        for memberId in group.members {
            initialActions[memberId] = "pending"
        }
        
        try await db.collection("groups").document(groupId).updateData([
            "deletionStatus": "requested",
            "memberActions": initialActions,
            "updatedAt": Date()
        ])
    }
    
    /// Process user's decision to Keep or Delete history
    func submitDeletionAction(group: FirestoreModels.Group, action: String) async throws {
        guard let groupId = group.id, let userId = userId else { return }
        
        let batch = db.batch()
        let groupRef = db.collection("groups").document(groupId)
        
        // 1. Handle Data Migration based on Action
        if action == "keep" {
            // A. Keep Data -> Detach SplitRequests from Group
            let requests = try await db.collection("split_requests")
                .whereField("groupId", isEqualTo: groupId)
                .whereFilter(Filter.orFilter([
                    Filter.whereField("fromUid", isEqualTo: userId),
                    Filter.whereField("toUid", isEqualTo: userId)
                ]))
                .getDocuments()
            
            for doc in requests.documents {
                batch.updateData(["groupId": NSNull()], forDocument: doc.reference)
            }
            
        } else if action == "delete" {
            // B. Delete Data -> Hard Delete Requests & Personal Transactions
            
            // Delete Split Requests
            let requests = try await db.collection("split_requests")
                .whereField("groupId", isEqualTo: groupId)
                .whereFilter(Filter.orFilter([
                    Filter.whereField("fromUid", isEqualTo: userId),
                    Filter.whereField("toUid", isEqualTo: userId)
                ]))
                .getDocuments()
            
            for doc in requests.documents {
                batch.deleteDocument(doc.reference)
            }
            
            // Delete Personal Transactions linked to this group
            let transactionIds = requests.documents.compactMap { $0.data()["transactionId"] as? String }
            let uniqueTxIds = Set(transactionIds)
            
            for txId in uniqueTxIds {
                let txRef = db.collection("users").document(userId).collection("transactions").document(txId)
                batch.deleteDocument(txRef)
            }
        }
        
        // Execute batch for user's personal data cleanup first
        try await batch.commit()
        
        // 2. Perform atomic update for Group membership and check for completion
        let result = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let doc: DocumentSnapshot
            do {
                doc = try transaction.getDocument(groupRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let groupData = try? doc.data(as: FirestoreModels.Group.self) else { return false }
            
            var actions = groupData.memberActions ?? [:]
            actions[userId] = action
            
            // After this user finishes, check if all original members have acted.
            // Note: We check against groupData.members (which still includes the user in the snapshot).
            let allComplete = groupData.members.allSatisfy { memberId in
                if memberId == userId { return true } // This user just acted
                let status = actions[memberId]
                return status == "keep" || status == "delete"
            }
            
            transaction.updateData([
                "memberActions.\(userId)": action,
                "members": FieldValue.arrayRemove([userId]),
                "memberNames.\(userId)": FieldValue.delete()
            ], forDocument: groupRef)
            
            return allComplete
        }
        
        // 3. Check if all members are done -> Final Hard Delete
        if let allComplete = result as? Bool, allComplete {
            try await finalizeGroupDeletion(groupId: groupId)
        }
    }
    
    private func finalizeGroupDeletion(groupId: String) async throws {
        // Hard delete the group document
        // Subcollections (transactions) usually need manual recursive delete in Firestore, 
        // but for now we delete the parent. A backend trigger usually handles subcollection cleanup.
        try await db.collection("groups").document(groupId).delete()
    }
    
    func leaveGroup(groupId: String, userId: String, keepData: Bool) async throws {
        // FIX 2.4: Check for outstanding balances before allowing leave
        let hasBalance = await hasOutstandingBalance(groupId: groupId, userId: userId)
        if hasBalance {
            throw NSError(domain: "GroupRepository", code: 409,
                          userInfo: [NSLocalizedDescriptionKey: "You must settle all debts before leaving the group."])
        }
        
        let batch = db.batch()
        let groupRef = db.collection("groups").document(groupId)
        
        // 1. Handle data migration based on user's choice (same logic as submitDeletionAction)
        if keepData {
            // A. Keep Data → Detach SplitRequests from Group
            let requests = try await db.collection("split_requests")
                .whereField("groupId", isEqualTo: groupId)
                .whereFilter(Filter.orFilter([
                    Filter.whereField("fromUid", isEqualTo: userId),
                    Filter.whereField("toUid", isEqualTo: userId)
                ]))
                .getDocuments()
            
            for doc in requests.documents {
                batch.updateData(["groupId": NSNull()], forDocument: doc.reference)
            }
        } else {
            // B. Delete Data → Hard Delete Requests & Personal Transactions
            let requests = try await db.collection("split_requests")
                .whereField("groupId", isEqualTo: groupId)
                .whereFilter(Filter.orFilter([
                    Filter.whereField("fromUid", isEqualTo: userId),
                    Filter.whereField("toUid", isEqualTo: userId)
                ]))
                .getDocuments()
            
            for doc in requests.documents {
                batch.deleteDocument(doc.reference)
            }
            
            // Delete linked personal transactions
            let transactionIds = requests.documents.compactMap { $0.data()["transactionId"] as? String }
            let uniqueTxIds = Set(transactionIds)
            
            for txId in uniqueTxIds {
                let txRef = db.collection("users").document(userId).collection("transactions").document(txId)
                batch.deleteDocument(txRef)
            }
        }
        
        // 2. Remove user from members array and memberNames map
        batch.updateData([
            "members": FieldValue.arrayRemove([userId]),
            "memberNames.\(userId)": FieldValue.delete()
        ], forDocument: groupRef)
        
        try await batch.commit()
    }
    
    /// FIX 2.4: Check if user has outstanding (unsettled) splits in the group
    func hasOutstandingBalance(groupId: String, userId: String) async -> Bool {
        // Check splits where user owes someone (toUid == user, pending/accepted)
        let owedSnapshot = try? await db.collection("split_requests")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("toUid", isEqualTo: userId)
            .whereField("status", in: ["pending", "accepted"])
            .getDocuments()
        
        if let count = owedSnapshot?.documents.count, count > 0 { return true }
        
        // Check splits where user is owed (fromUid == user, pending/accepted)
        let owingSnapshot = try? await db.collection("split_requests")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("fromUid", isEqualTo: userId)
            .whereField("status", in: ["pending", "accepted"])
            .getDocuments()
        
        if let count = owingSnapshot?.documents.count, count > 0 { return true }
        
        return false
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
