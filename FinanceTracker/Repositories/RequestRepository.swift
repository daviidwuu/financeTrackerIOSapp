import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class RequestRepository: ObservableObject {
    @Published var requests: [FirestoreModels.SplitRequest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    func startListening(userId: String) {
        stopListening()
        // Only show loading if we don't have any data yet (Stale-While-Revalidate)
        if requests.isEmpty {
            self.isLoading = true
        }
        self.errorMessage = nil
        
        // v2.1: Listen to root `split_requests` where `toUid` == currentUserId
        // FIX #16: Include both pending and accepted statuses (not just pending)
        // so users can see requests they need to pay
        listenerRegistration = db.collection("split_requests")
            .whereField("toUid", isEqualTo: userId)
            .whereField("status", in: [
                FirestoreModels.SplitRequest.RequestStatus.pending.rawValue,
                FirestoreModels.SplitRequest.RequestStatus.accepted.rawValue
            ])
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error fetching requests: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    self.errorMessage = "No requests found."
                    return
                }
                
                self.errorMessage = nil
                self.requests = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.SplitRequest.self)
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
    
    func updateRequestStatus(userId: String, requestId: String, status: FirestoreModels.SplitRequest.RequestStatus, lastUpdatedBy: String? = nil) async throws {
        // v2.1: Update root collection document
        var updateData: [String: Any] = [
            "status": status.rawValue
        ]
        if let updatedBy = lastUpdatedBy {
            updateData["lastUpdatedBy"] = updatedBy
        }
        try await db.collection("split_requests").document(requestId).updateData(updateData)
    }
    
    func deleteRequest(requestId: String) async throws {
        // v2.1: Delete from root collection
        try await db.collection("split_requests").document(requestId).delete()
    }
}
