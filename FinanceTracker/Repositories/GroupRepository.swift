import Foundation
import FirebaseFirestore
import Combine

class GroupRepository: ObservableObject {

    // MARK: - Properties

    private let db = Firestore.firestore()
    @Published var groups: [FirestoreModels.Group] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil

    private var userId: String?
    private var listener: ListenerRegistration?

    // MARK: - Firestore Path Helpers

    private var groupsCollection: CollectionReference {
        db.collection("groups")
    }

    private func groupRef(_ groupId: String) -> DocumentReference {
        groupsCollection.document(groupId)
    }

    private func splitRequestsQuery(groupId: String, userId: String) -> Query {
        db.collection("split_requests")
            .whereField("groupId", isEqualTo: groupId)
            .whereFilter(Filter.orFilter([
                Filter.whereField("fromUid", isEqualTo: userId),
                Filter.whereField("toUid", isEqualTo: userId)
            ]))
    }

    private func userTransactionRef(userId: String, transactionId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("transactions").document(transactionId)
    }

    // MARK: - Lifecycle

    deinit {
        listener?.remove()
    }

    // MARK: - Listener Management

    func startListening(userId: String) {
        // Guard against duplicate listener registration if already listening for this user.
        if self.userId == userId && listener != nil { return }

        // Remove any previous listener before registering a new one.
        listener?.remove()

        self.userId = userId
        // Only show loading indicator when the local cache is empty (Stale-While-Revalidate).
        if groups.isEmpty {
            self.isLoading = true
        }
        self.errorMessage = nil

        listener = groupsCollection
            .whereField("members", arrayContains: userId)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Error fetching groups: \(error.localizedDescription)"
                    DebugLogger.log("GroupRepository: error fetching groups: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No groups found."
                    return
                }

                self.errorMessage = nil
                self.groups = documents.compactMap { try? $0.data(as: FirestoreModels.Group.self) }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        userId = nil
        groups = []
    }

    // MARK: - Group CRUD

    /// Creates a new group. Returns the new group's Firestore document ID.
    func addGroup(_ group: FirestoreModels.Group) async throws -> String {
        guard let userId = userId else {
            throw NSError(domain: "GroupRepository", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }

        let ref = groupsCollection.document()

        var newGroup = group
        newGroup.id = ref.documentID
        newGroup.createdBy = userId
        newGroup.createdAt = Date()
        newGroup.updatedAt = Date()
        newGroup.normalizedName = group.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Ensure creator is always a member.
        if !newGroup.members.contains(userId) {
            newGroup.members.append(userId)
        }

        var data = try Firestore.Encoder().encode(newGroup)
        data["lastUpdatedBy"] = userId

        // Optimistic UI update — listener will confirm or revert.
        await MainActor.run {
            self.groups.insert(newGroup, at: 0)
            self.groups.sort { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
        }

        try await ref.setData(data)
        return ref.documentID
    }

    /// Updates an existing group's metadata. Uses merge so unrelated fields are preserved.
    func updateGroup(_ group: FirestoreModels.Group) async throws {
        guard let groupId = group.id else {
            throw NSError(domain: "GroupRepository", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Group has no ID."])
        }

        var updatedGroup = group
        updatedGroup.updatedAt = Date()
        updatedGroup.normalizedName = group.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Optimistic UI update — listener will confirm or revert.
        await MainActor.run {
            if let index = self.groups.firstIndex(where: { $0.id == groupId }) {
                self.groups[index] = updatedGroup
                self.groups.sort { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            }
        }

        // `setData(from:merge:)` is a synchronous throwing Codable helper in this SDK.
        try groupRef(groupId).setData(from: updatedGroup, merge: true)
    }

    /// Hard-deletes a group document. Security Rules enforce that only the creator can do this.
    /// Note: Firestore does not recursively delete subcollections from the client; a backend trigger
    /// (e.g. Firebase Extension "Delete User Data" or a Cloud Function) must handle subcollection cleanup.
    func deleteGroup(groupId: String) async throws {
        // Fetch the group to obtain its member list for cleanup.
        let snapshot = try await groupRef(groupId).getDocument()
        guard let group = try? snapshot.data(as: FirestoreModels.Group.self) else {
            throw NSError(domain: "GroupRepository", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Group not found."])
        }

        let batch = db.batch()

        // Mark the group document for deletion.
        batch.deleteDocument(groupRef(groupId))

        // Remove the group from each member's perspective (denormalized group list, if any).
        // The `members` array on the group doc is the source of truth; if user docs mirror
        // group membership, those references must be cleaned up here.
        // Currently group membership is derived from the root `groups` collection query,
        // so no per-user document cleanup is needed beyond deleting the group itself.
        // If a per-user `groupIds` array is introduced, add batch.updateData here per member.

        _ = group // suppress unused warning; group data used for future per-member cleanup

        try await batch.commit()
    }

    // MARK: - Group Membership

    /// Adds multiple members to a group, updating both the `members` array and the
    /// denormalized `memberNames` map in a single atomic write.
    func addMembersToGroup(groupId: String, newMembers: [(id: String, name: String)]) async throws {
        let newMemberIds = newMembers.map { $0.id }

        var updateData: [String: Any] = [
            "members": FieldValue.arrayUnion(newMemberIds),
            "updatedAt": Date()
        ]

        // Use dot-notation keys to merge individual name entries without overwriting the whole map.
        for member in newMembers {
            updateData["memberNames.\(member.id)"] = member.name
        }

        try await groupRef(groupId).updateData(updateData)
    }

    /// Returns true if `uid` is a member of the given group (synchronous cache lookup).
    func isMember(groupId: String, uid: String) -> Bool {
        guard let group = groups.first(where: { $0.id == groupId }) else { return false }
        return group.members.contains(uid)
    }

    // MARK: - Leave Group

    /// Removes the current user from a group after verifying they have no outstanding balance.
    /// - Parameters:
    ///   - groupId: The group to leave.
    ///   - userId: The user leaving.
    ///   - keepData: If true, detaches the user's split requests from the group; if false, deletes them.
    func leaveGroup(groupId: String, userId: String, keepData: Bool) async throws {
        // Verify zero net balance before allowing leave.
        let hasBalance = try await hasOutstandingBalance(groupId: groupId, userId: userId)
        if hasBalance {
            throw NSError(domain: "GroupRepository", code: 409,
                          userInfo: [NSLocalizedDescriptionKey: "You must settle all debts before leaving the group."])
        }

        let batch = db.batch()
        let ref = groupRef(groupId)

        // Apply data migration based on user's choice.
        try await applyDataMigration(
            batch: batch,
            groupId: groupId,
            userId: userId,
            keepData: keepData
        )

        // Remove user from members array and denormalized name map.
        batch.updateData([
            "members": FieldValue.arrayRemove([userId]),
            "memberNames.\(userId)": FieldValue.delete(),
            "updatedAt": Date()
        ], forDocument: ref)

        try await batch.commit()
    }

    // MARK: - Group Deletion Flow (Soft Delete)

    /// Marks the group as deletion-requested and initialises each member's action to "pending".
    func requestGroupDeletion(group: FirestoreModels.Group) async throws {
        guard let groupId = group.id else {
            throw NSError(domain: "GroupRepository", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Group has no ID."])
        }

        var initialActions: [String: String] = [:]
        for memberId in group.members {
            initialActions[memberId] = "pending"
        }

        try await groupRef(groupId).updateData([
            "deletionStatus": "requested",
            "memberActions": initialActions,
            "updatedAt": Date()
        ])
    }

    /// Records the current user's keep/delete decision during a group deletion flow.
    /// When all members have acted, triggers the final hard delete.
    func submitDeletionAction(group: FirestoreModels.Group, action: String) async throws {
        guard let groupId = group.id, let userId = userId else {
            throw NSError(domain: "GroupRepository", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Missing group ID or user session."])
        }

        let ref = groupRef(groupId)
        let batch = db.batch()

        // Migrate personal data based on the user's chosen action.
        try await applyDataMigration(
            batch: batch,
            groupId: groupId,
            userId: userId,
            keepData: action == "keep"
        )
        try await batch.commit()

        // Atomically record the user's action and remove them from the members list.
        let allComplete = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let doc: DocumentSnapshot
            do {
                doc = try transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard let groupData = try? doc.data(as: FirestoreModels.Group.self) else {
                return false
            }

            var actions = groupData.memberActions ?? [:]
            actions[userId] = action

            // Check whether all members (including the one acting now) have submitted.
            let allDone = groupData.members.allSatisfy { memberId in
                if memberId == userId { return true } // This user just acted.
                let status = actions[memberId]
                return status == "keep" || status == "delete"
            }

            transaction.updateData([
                "memberActions.\(userId)": action,
                "members": FieldValue.arrayRemove([userId]),
                "memberNames.\(userId)": FieldValue.delete()
            ], forDocument: ref)

            return allDone
        }

        // If every member has acted, perform the final hard delete.
        if let allDone = allComplete as? Bool, allDone {
            try await finalizeGroupDeletion(groupId: groupId)
        }
    }

    // MARK: - Balance Check

    /// Returns true if the user has any unsettled split requests (pending or accepted) in the group.
    /// Throws on Firestore error so callers can surface the failure rather than silently allowing leave.
    func hasOutstandingBalance(groupId: String, userId: String) async throws -> Bool {
        // Splits where the user owes someone else (toUid == user).
        let owedSnapshot = try await db.collection("split_requests")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("toUid", isEqualTo: userId)
            .whereField("status", in: ["pending", "accepted"])
            .getDocuments()

        if !owedSnapshot.documents.isEmpty { return true }

        // Splits where someone owes the user (fromUid == user).
        let owingSnapshot = try await db.collection("split_requests")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("fromUid", isEqualTo: userId)
            .whereField("status", in: ["pending", "accepted"])
            .getDocuments()

        return !owingSnapshot.documents.isEmpty
    }

    // MARK: - Private Helpers

    /// Applies data migration batch operations for a user's split requests in a group.
    /// - Parameters:
    ///   - batch: The Firestore batch to append operations to.
    ///   - groupId: Group whose data is being migrated.
    ///   - userId: User whose data is being migrated.
    ///   - keepData: If true, detaches requests from the group; if false, deletes them and linked transactions.
    private func applyDataMigration(
        batch: WriteBatch,
        groupId: String,
        userId: String,
        keepData: Bool
    ) async throws {
        let requests = try await splitRequestsQuery(groupId: groupId, userId: userId).getDocuments()

        if keepData {
            // Detach split requests from the group so the user retains the history.
            for doc in requests.documents {
                batch.updateData(["groupId": NSNull()], forDocument: doc.reference)
            }
        } else {
            // Hard-delete split requests and the linked personal transactions.
            for doc in requests.documents {
                batch.deleteDocument(doc.reference)
            }

            let linkedTxIds = Set(requests.documents.compactMap { $0.data()["transactionId"] as? String })
            for txId in linkedTxIds {
                batch.deleteDocument(userTransactionRef(userId: userId, transactionId: txId))
            }
        }
    }

    /// Performs the final hard delete of a group document once all members have acted.
    private func finalizeGroupDeletion(groupId: String) async throws {
        // Deletes the parent document. A backend trigger must handle subcollection cleanup
        // (e.g. nested `transactions` subcollection) since the Firestore client SDK does
        // not recursively delete subcollections.
        try await groupRef(groupId).delete()
    }
}
