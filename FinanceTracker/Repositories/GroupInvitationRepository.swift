import Foundation
import FirebaseFirestore
import Combine

class GroupInvitationRepository: ObservableObject {
    @Published var incomingInvitations: [FirestoreModels.GroupInvitation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func startListening(userId: String) {
        // Only show loading if we don't have any data yet (Stale-While-Revalidate)
        if incomingInvitations.isEmpty {
            self.isLoading = true
        }
        self.errorMessage = nil
        
        listener = db.collection("group_invitations")
            .whereField("toUid", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error fetching invitations: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                self.incomingInvitations = documents.compactMap { try? $0.data(as: FirestoreModels.GroupInvitation.self) }
            }
    }
    
    func stopListening() {
        listener?.remove()
        incomingInvitations = []
    }
    
    func acceptInvitation(_ invitation: FirestoreModels.GroupInvitation) async throws {
        guard let inviteId = invitation.id else { return }
        
        let batch = db.batch()
        
        // 1. Update Invitation Status
        let inviteRef = db.collection("group_invitations").document(inviteId)
        batch.updateData(["status": "accepted"], forDocument: inviteRef)
        
        // 2. Gap #2 Fix: Removed duplicate group member write.
        // The Cloud Function `v2_onGroupInvitationUpdated` handles adding the member
        // to the group atomically when it detects status → "accepted".
        
        // 3. Find and Unblock Dependent Requests
        let dependentRequests = try await db.collection("split_requests")
            .whereField("dependencyId", isEqualTo: inviteId)
            .getDocuments()
            
        for doc in dependentRequests.documents {
            batch.updateData(["status": FirestoreModels.SplitRequest.RequestStatus.pending.rawValue], forDocument: doc.reference)
        }
        
        try await batch.commit()
    }
    
    func declineInvitation(_ invitation: FirestoreModels.GroupInvitation) async throws {
        guard let inviteId = invitation.id else { return }
        try await db.collection("group_invitations").document(inviteId).updateData(["status": "declined"])
    }
}
