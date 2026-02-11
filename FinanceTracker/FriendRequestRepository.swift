import Foundation
import FirebaseFirestore

import Combine

class FriendRequestRepository: ObservableObject {
    @Published var incomingRequests: [FirestoreModels.FriendRequest] = []
    @Published var outgoingRequests: [FirestoreModels.FriendRequest] = []
    
    private let db = Firestore.firestore()
    private var incomingListener: ListenerRegistration?
    private var outgoingListener: ListenerRegistration?
    
    func startListening(userId: String) {
        // Listen to incoming requests (requests sent TO me)
        incomingListener = db.collection("friend_requests")
            .whereField("toUid", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching incoming requests: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                self?.incomingRequests = documents.compactMap { try? $0.data(as: FirestoreModels.FriendRequest.self) }
            }
        
        // Listen to outgoing requests (requests I sent)
        outgoingListener = db.collection("friend_requests")
            .whereField("fromUid", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching outgoing requests: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                self?.outgoingRequests = documents.compactMap { try? $0.data(as: FirestoreModels.FriendRequest.self) }
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
        try await db.collection("friend_requests").document(reqId).updateData(["status": "accepted"])
    }
    
    func declineRequest(_ request: FirestoreModels.FriendRequest) async throws {
        guard let reqId = request.id else { return }
        try await db.collection("friend_requests").document(reqId).updateData(["status": "declined"])
    }
    
    func stopListening() {
        incomingListener?.remove()
        outgoingListener?.remove()
        incomingRequests = []
        outgoingRequests = []
    }
}
