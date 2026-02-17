import Foundation
import FirebaseFirestore

import Combine

class FriendRequestRepository: ObservableObject {
    @Published var incomingRequests: [FirestoreModels.FriendRequest] = []
    @Published var outgoingRequests: [FirestoreModels.FriendRequest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let db = Firestore.firestore()
    private var incomingListener: ListenerRegistration?
    private var outgoingListener: ListenerRegistration?
    
    func startListening(userId: String) {
        // Only show loading if we don't have any data yet (Stale-While-Revalidate)
        if incomingRequests.isEmpty && outgoingRequests.isEmpty {
            self.isLoading = true
        }
        self.errorMessage = nil
        
        // Listen to incoming requests (requests sent TO me)
        incomingListener = db.collection("friend_requests")
            .whereField("toUid", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error fetching incoming requests: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                self.incomingRequests = documents.compactMap { try? $0.data(as: FirestoreModels.FriendRequest.self) }
            }
        
        // Listen to outgoing requests (requests I sent)
        outgoingListener = db.collection("friend_requests")
            .whereField("fromUid", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                // We don't necessarily toggle isLoading here again if incoming handled it, but it's safe.
                
                if let error = error {
                    self.errorMessage = "Error fetching outgoing requests: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                self.outgoingRequests = documents.compactMap { try? $0.data(as: FirestoreModels.FriendRequest.self) }
            }
    }
    
    func sendFriendRequest(fromUid: String, fromName: String, fromUsername: String, toUid: String) async throws {
        let request = FirestoreModels.FriendRequest(
            fromUid: fromUid,
            toUid: toUid,
            status: "pending",
            fromName: fromName,
            fromUsername: fromUsername,
            createdAt: Date()
        )
        try db.collection("friend_requests").document().setData(from: request)
    }
    
    func acceptRequest(_ request: FirestoreModels.FriendRequest) async throws {
        guard let reqId = request.id else { return }
        
        // Optimistic update: Remove from local list immediately
        if let index = incomingRequests.firstIndex(where: { $0.id == reqId }) {
            incomingRequests.remove(at: index)
        }
        
        try await db.collection("friend_requests").document(reqId).updateData(["status": "accepted"])
    }
    
    func declineRequest(_ request: FirestoreModels.FriendRequest) async throws {
        guard let reqId = request.id else { return }
        
        // Optimistic update: Remove from local list immediately
        if let index = incomingRequests.firstIndex(where: { $0.id == reqId }) {
            incomingRequests.remove(at: index)
        }
        
        try await db.collection("friend_requests").document(reqId).updateData(["status": "declined"])
    }
    
    func stopListening() {
        incomingListener?.remove()
        outgoingListener?.remove()
        incomingRequests = []
        outgoingRequests = []
    }
}
