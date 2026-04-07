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
    private var currentUserId: String?

    var incomingActionableRequests: [FirestoreModels.SplitRequest] {
        guard let currentUserId else { return requests }
        return requests.filter { $0.presentation(for: currentUserId).isVisibleOnHome }
    }
    
    var requestsForDetailContext: [FirestoreModels.SplitRequest] {
        requests
    }
    
    func startListening(userId: String) {
        stopListening()
        currentUserId = userId
        // Only show loading if we don't have any data yet (Stale-While-Revalidate)
        if requests.isEmpty {
            self.isLoading = true
        }
        self.errorMessage = nil
        
        // Home is an actionable inbox only: incoming requests that still need a response.
        listenerRegistration = db.collection("split_requests")
            .whereField("toUid", isEqualTo: userId)
            .whereField("status", isEqualTo: FirestoreModels.SplitRequest.RequestStatus.pending.rawValue)
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
        currentUserId = nil
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
        
        // 1. Fetch Request to see if it belongs to a group
        let requestRef = db.collection("split_requests").document(requestId)
        if let requestDoc = try? await requestRef.getDocument(),
           let request = try? requestDoc.data(as: FirestoreModels.SplitRequest.self),
           let groupId = request.groupId {
            
            // 2. Update Group Transaction optionally
            let groupTxs = try await db.collection("groups").document(groupId).collection("transactions")
                .whereField("originalTransactionId", isEqualTo: request.transactionId)
                .getDocuments()
                
            if let groupTxDoc = groupTxs.documents.first {
                try await groupTxDoc.reference.updateData([
                    "involvedUserStatuses.\(request.toUid)": status.rawValue
                ])
            }
        }
        
        // 3. Commit root update
        try await requestRef.updateData(updateData)
    }
    
    func deleteRequest(requestId: String) async throws {
        // v2.1: Delete from root collection
        try await db.collection("split_requests").document(requestId).delete()
    }
}
