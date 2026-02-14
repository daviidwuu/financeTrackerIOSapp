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
        
        // v2.1: Listen to root `split_requests` where `toUid` == currentUserId
        listenerRegistration = db.collection("split_requests")
            .whereField("toUid", isEqualTo: userId)
            .whereField("status", isEqualTo: FirestoreModels.SplitRequest.RequestStatus.pending.rawValue) // Only fetch pending
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                if let error = error {
                    print("❌ Error fetching requests: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("⚠️ Snapshot received but documents is nil")
                    return
                }
                
                print("✅ Received \(documents.count) pending requests for user \(userId)")
                
                self?.requests = documents.compactMap { document in
                    do {
                        let req = try document.data(as: FirestoreModels.SplitRequest.self)
                        print("   - Decoded request: \(req.id ?? "nil") from \(req.fromUid)")
                        return req
                    } catch {
                        print("❌ Error decoding SplitRequest (ID: \(document.documentID)): \(error)")
                        return nil
                    }
                }
            }
    }
    
    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        requests = []
    }
    
    // NOTE: Sending is now handled by SocialTransactionManager (Batch), 
    // but we keep this if needed for standalone requests later.
    // For now, we update it to use the root collection just in case.
    func sendRequest(request: FirestoreModels.SplitRequest) async throws -> String {
        let ref = try db.collection("split_requests").addDocument(from: request)
        return ref.documentID
    }
    
    func updateRequestStatus(userId: String, requestId: String, status: FirestoreModels.SplitRequest.RequestStatus) async throws {
        // v2.1: Update root collection document
        try await db.collection("split_requests").document(requestId).updateData([
            "status": status.rawValue
        ])
    }
    
    func deleteRequest(requestId: String) async throws {
        // v2.1: Delete from root collection
        try await db.collection("split_requests").document(requestId).delete()
    }
}
