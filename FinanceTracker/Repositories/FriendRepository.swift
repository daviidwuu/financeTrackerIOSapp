import Foundation
import FirebaseFirestore
import Combine

class FriendRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var friends: [FirestoreModels.Friend] = []
    @Published var searchResults: [UserSearchResult] = [] // Using the User struct from FirebaseManager (or defining a lightweight one)
    @Published var isLoading = true // ✅ NEW: Loading state
    private var userId: String?
    private var listener: ListenerRegistration?
    
    // Defines a lightweight User struct for search results since 'User' might be the Auth one
    struct UserSearchResult: Identifiable, Codable {
        @DocumentID var id: String?
        var name: String
        var username: String
        var email: String? // ✅ Fixed: Optional email
    }
    
    func startListening(userId: String) {
        self.userId = userId
        self.isLoading = true
        listener = db.collection("users").document(userId).collection("friends")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                guard let documents = snapshot?.documents else {
                    DebugLogger.log("Error fetching friends: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
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
    /// Note: Firestore doesn't support partial text search natively well.
    /// We will do an exact match or "process prefix" check if needed.
    /// For now, let's do exact match or simple >= query.
    func searchUsers(username: String) async throws -> [UserSearchResult] {
        guard !username.isEmpty else { return [] }
        
        // Case sensitive search is standard in Firestore unless we store a lowercase version.
        // Let's assume we store exactly as is for now, or the user inputs exact.
        // Check implementation plan: "Simple Firestore query check"
        
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username)
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
        // 1. Add 'From User' (Sender) to 'To User' (Receiver/Me) friends list
        let senderAsFriend = FirestoreModels.Friend(
            id: fromUser.uid,
            username: fromUser.username,
            name: fromUser.name,
            email: nil, // Email not available in request
            addedAt: Date()
        )
        try db.collection("users").document(toUser.uid).collection("friends").document(fromUser.uid).setData(from: senderAsFriend)
        
        // 2. Add 'To User' (Receiver/Me) to 'From User' (Sender) friends list
        let receiverAsFriend = FirestoreModels.Friend(
            id: toUser.uid,
            username: toUser.username,
            name: toUser.name,
            email: toUser.email,
            addedAt: Date()
        )
        try db.collection("users").document(fromUser.uid).collection("friends").document(toUser.uid).setData(from: receiverAsFriend)
        
        // 3. Update Request Status
        try await db.collection("friend_requests").document(requestId).updateData(["status": "accepted"])
    }
}
