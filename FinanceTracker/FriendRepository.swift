import Foundation
import FirebaseFirestore
import Combine

class FriendRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var friends: [FirestoreModels.Friend] = []
    @Published var searchResults: [UserSearchResult] = [] // Using the User struct from FirebaseManager (or defining a lightweight one)
    private var userId: String?
    private var listener: ListenerRegistration?
    
    // Defines a lightweight User struct for search results since 'User' might be the Auth one
    struct UserSearchResult: Identifiable, Codable {
        @DocumentID var id: String?
        var name: String
        var username: String
        var email: String
    }
    
    func startListening(userId: String) {
        self.userId = userId
        listener = db.collection("users").document(userId).collection("friends")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    DebugLogger.log("Error fetching friends: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.friends = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.Friend.self)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
        friends = []
    }
    
    /// User A adds User B
    /// - Parameters:
    ///   - currentUserId: ID of the user performing the add
    ///   - currentUserInfo: (username, name, email) of current user to add to target's list
    ///   - targetUser: The user being added
    func addFriend(currentUserId: String, currentUserInfo: (username: String, name: String, email: String), targetUser: UserSearchResult) async throws {
        
        let batch = db.batch()
        
        // 1. Add Target to Current User's list
        let friendForCurrent = FirestoreModels.Friend(
            username: targetUser.username,
            name: targetUser.name,
            email: targetUser.email,
            addedAt: Date()
        )
        // Use target's ID as the document ID in the friends collection
        let currentRef = db.collection("users").document(currentUserId).collection("friends").document(targetUser.id!)
        try batch.setData(from: friendForCurrent, forDocument: currentRef)
        
        // 2. Add Current User to Target's list
        let friendForTarget = FirestoreModels.Friend(
            username: currentUserInfo.username,
            name: currentUserInfo.name,
            email: currentUserInfo.email,
            addedAt: Date()
        )
        let targetRef = db.collection("users").document(targetUser.id!).collection("friends").document(currentUserId)
        try batch.setData(from: friendForTarget, forDocument: targetRef)
        
        try await batch.commit()
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
        
        let batch = db.batch()
        
        // Remove from my list
        let myRef = db.collection("users").document(userId).collection("friends").document(friendId)
        batch.deleteDocument(myRef)
        
        // Remove me from their list
        // Note: This assumes we want to break the link both ways. 
        // Some apps allow one-way, but user asked for "added to both", so deleting from both makes sense to keep in sync.
        let theirRef = db.collection("users").document(friendId).collection("friends").document(userId)
        batch.deleteDocument(theirRef)
        
        try await batch.commit()
    }
}
