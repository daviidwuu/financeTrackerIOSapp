import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class RequestRepository: ObservableObject {
    @Published var requests: [FirestoreModels.SplitRequest] = []
    
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    func startListening(userId: String) {
        stopListening()
        
        listenerRegistration = db.collection("users").document(userId).collection("requests")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    DebugLogger.log("Error fetching requests: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.requests = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.SplitRequest.self)
                }
            }
    }
    
    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        requests = []
    }
    
    func sendRequest(to friendId: String, request: FirestoreModels.SplitRequest) async throws -> String {
        let ref = try db.collection("users").document(friendId).collection("requests").addDocument(from: request)
        return ref.documentID
    }
    
    func updateRequestStatus(userId: String, requestId: String, status: String) async throws {
        try await db.collection("users").document(userId).collection("requests").document(requestId).updateData([
            "status": status
        ])
    }
    
    func deleteRequest(userId: String, requestId: String) async throws {
        try await db.collection("users").document(userId).collection("requests").document(requestId).delete()
    }
}
