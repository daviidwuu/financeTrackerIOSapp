import Foundation
import FirebaseFirestore
import Combine

class FriendRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var friends: [FirestoreModels.Friend] = []
    @Published var searchResults: [UserSearchResult] = [] // Using the User struct from FirebaseManager (or defining a lightweight one)
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    
    private var userId: String?
    private var listener: ListenerRegistration?
    
    // Defines a lightweight User struct for search results since 'User' might be the Auth one
    struct UserSearchResult: Identifiable, Codable {
        @DocumentID var id: String?
        var name: String
        var username: String
        var email: String?
    }
    
    func startListening(userId: String) {
        self.userId = userId
        // Only show loading if we don't have any data yet (Stale-While-Revalidate)
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
                    DebugLogger.log("Error fetching friends: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No friends found."
                    return
                }
                
                self.errorMessage = nil
                self.friends = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.Friend.self)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
        friends = []
    }
    
    /// User A sends a Friend Request to User B (v2.1 Request Flow)
    /// - Parameters:
    ///   - currentUserId: ID of the user performing the add
    ///   - currentUserInfo: (username, name, email) of current user to add to target's list
    ///   - targetUser: The user being added
    func addFriend(currentUserId: String, currentUserInfo: (username: String, name: String, email: String), targetUser: UserSearchResult) async throws {
        // v2.1: Redirect to Friend Request Flow
        let request = FirestoreModels.FriendRequest(
            fromUid: currentUserId,
            toUid: targetUser.id!,
            status: "pending",
            createdAt: Date()
        )
        try db.collection("friend_requests").document().setData(from: request)
    }
    
    /// Check if a user is already a friend (Synchronous Cache Lookup)
    func isFriend(uid: String) -> Bool {
        return friends.contains(where: { $0.id == uid })
    }
    
    /// Search for users by username
    /// Uses >= and <= for prefix matching to support "starts with" search.
    func searchUsers(username: String) async throws -> [UserSearchResult] {
        guard !username.isEmpty else { return [] }
        
        // Case sensitive search is standard in Firestore unless we store a lowercase version.
        // Assuming 'username' field is indexed.
        
        let queryText = username
        let endText = queryText + "\u{f8ff}"
        
        let snapshot = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: queryText)
            .whereField("username", isLessThanOrEqualTo: endText)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: UserSearchResult.self) }
    }
    
    func deleteFriend(friendId: String) async throws {
        guard let userId = userId else { return }
        
        // 1. Remove from my list (Primary Action)
        // The Cloud Function `v2_onFriendDeleted` will handle removing me from their list.
        let myRef = db.collection("users").document(userId).collection("friends").document(friendId)
        try await myRef.delete()
    }
    
    /// Create bidirectional friendship (Client-side fallback for Phase 6 Cloud Functions)
    func createFriendship(requestId: String, fromUser: (uid: String, name: String, username: String), toUser: (uid: String, name: String, username: String, email: String)) async throws {
        // 1. Critical Batch: Add 'From User' to 'My' friends list AND Update Request Status
        // We prioritize this because we have permission to write to our own collection.
        let batch = db.batch()
        
        let senderAsFriend = FirestoreModels.Friend(
            id: fromUser.uid,
            username: fromUser.username,
            name: fromUser.name,
            email: nil, // Email not available in request
            avatarColor: nil, // Will be updated by Cloud Function
            addedAt: Date()
        )
        // 'toUser' is Me (Receiver of request)
        let myFriendRef = db.collection("users").document(toUser.uid).collection("friends").document(fromUser.uid)
        try batch.setData(from: senderAsFriend, forDocument: myFriendRef)
        
        let requestRef = db.collection("friend_requests").document(requestId)
        batch.updateData(["status": "accepted"], forDocument: requestRef)
        
        try await batch.commit()
    }
}
