import Foundation
import FirebaseFirestore
import Combine

class GroupRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var groups: [FirestoreModels.Group] = []
    private var userId: String?
    private var listener: ListenerRegistration?
    
    func startListening(userId: String) {
        self.userId = userId
        listener = db.collection("users").document(userId).collection("groups")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    DebugLogger.log("Error fetching groups: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.groups = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.Group.self)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
        groups = []
    }
    
    func addGroup(_ group: FirestoreModels.Group) async throws -> String {
        guard let userId = userId else { throw NSError(domain: "GroupRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]) }
        let ref = db.collection("users").document(userId).collection("groups").document()
        
        var newGroup = group
        newGroup.id = ref.documentID
        
        try ref.setData(from: newGroup)
        return ref.documentID
    }
    
    func deleteGroup(groupId: String) async throws {
        guard let userId = userId else { return }
        try await db.collection("users").document(userId).collection("groups").document(groupId).delete()
    }
}
