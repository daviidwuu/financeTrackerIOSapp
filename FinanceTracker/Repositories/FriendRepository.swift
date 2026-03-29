import Foundation
import FirebaseFirestore
import Combine

class FriendRepository: ObservableObject {

    // MARK: - Properties

    private let db = Firestore.firestore()
    @Published var friends: [FirestoreModels.Friend] = []
    @Published var searchResults: [UserSearchResult] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil

    private var userId: String?
    private var listener: ListenerRegistration?

    // MARK: - Nested Types

    /// Lightweight result type for user search — distinct from the Auth User type.
    struct UserSearchResult: Identifiable, Codable {
        @DocumentID var id: String?
        var name: String
        var username: String
        var email: String?
        var isPremium: Bool?
        var badgeType: String?
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
        if friends.isEmpty {
            self.isLoading = true
        }
        self.errorMessage = nil

        listener = db.collection("users").document(userId).collection("friends")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Error fetching friends: \(error.localizedDescription)"
                    DebugLogger.log("FriendRepository: error fetching friends: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No friends found."
                    return
                }

                self.errorMessage = nil
                self.friends = documents.compactMap { try? $0.data(as: FirestoreModels.Friend.self) }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        userId = nil
        friends = []
    }

    // MARK: - Friend Requests

    /// Sends a friend request from the current user to `targetUser`.
    /// Creates a `FriendRequest` document with status "pending".
    /// The Cloud Function `v2_onFriendRequestUpdated` creates both friend documents atomically on accept.
    func addFriend(
        currentUserId: String,
        currentUserInfo: (username: String, name: String, email: String),
        targetUser: UserSearchResult
    ) async throws {
        guard let targetId = targetUser.id else {
            throw NSError(domain: "FriendRepository", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Target user has no ID."])
        }

        let request = FirestoreModels.FriendRequest(
            fromUid: currentUserId,
            toUid: targetId,
            status: "pending",
            fromName: currentUserInfo.name,
            fromUsername: currentUserInfo.username,
            createdAt: Date()
        )
        // Use async setData so the caller can properly await and catch errors.
        try await db.collection("friend_requests").document().setData(from: request)
    }

    /// Accepts a pending friend request by updating its status to "accepted".
    /// Bidirectional friendship creation is handled atomically by the Cloud Function
    /// `v2_onFriendRequestUpdated`, which writes both users' friend sub-collections.
    func createFriendship(
        requestId: String,
        fromUser: (uid: String, name: String, username: String),
        toUser: (uid: String, name: String, username: String, email: String)
    ) async throws {
        let requestRef = db.collection("friend_requests").document(requestId)
        try await requestRef.updateData(["status": "accepted"])
    }

    /// Declines a pending friend request by updating its status to "declined".
    func declineFriendRequest(requestId: String) async throws {
        let requestRef = db.collection("friend_requests").document(requestId)
        try await requestRef.updateData(["status": "declined"])
    }

    /// Cancels an outgoing friend request by deleting the document.
    func cancelFriendRequest(requestId: String) async throws {
        try await db.collection("friend_requests").document(requestId).delete()
    }

    // MARK: - Friend Management

    /// Removes a friend from the current user's friend list.
    /// The Cloud Function `v2_onFriendDeleted` mirrors this deletion on the other user's list,
    /// ensuring bidirectionality without requiring an extra client-side write.
    func deleteFriend(friendId: String) async throws {
        guard let userId = userId else {
            throw NSError(domain: "FriendRepository", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }

        let myRef = db.collection("users").document(userId)
            .collection("friends").document(friendId)
        try await myRef.delete()
    }

    /// Returns true if `uid` is in the local friends cache (synchronous).
    func isFriend(uid: String) -> Bool {
        return friends.contains(where: { $0.id == uid })
    }

    // MARK: - User Search

    /// Searches for users whose username starts with `username` (case-insensitive prefix match).
    func searchUsers(username: String) async throws -> [UserSearchResult] {
        guard !username.isEmpty else { return [] }

        let queryText = username.lowercased()
        let endText = queryText + "\u{f8ff}"

        let snapshot = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: queryText)
            .whereField("username", isLessThanOrEqualTo: endText)
            .getDocuments()

        let results = snapshot.documents.compactMap { try? $0.data(as: UserSearchResult.self) }
        await MainActor.run {
            self.searchResults = results
        }
        return results
    }
}
