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
        
        // 2. Add Member to Group (Client-side Fallback / Redundancy)
        // Note: Security rules might prevent this if only owner can add, 
        // but typically "accepting" an invite should allow joining.
        // If rules are strict, this might fail and rely on Cloud Function.
        // For now, we assume strict rules are NOT blocking this specific write or we rely on the backend.
        // However, to ensure "Instant Feedback", we want to update the UI immediately.
        // The GroupRepository listener should pick this up if the backend updates it.
        // If we want immediate local update, we can't easily force it without writing to DB.
        
        // Let's try to write to the group members array.
        let groupRef = db.collection("groups").document(invitation.groupId)
        batch.updateData(["members": FieldValue.arrayUnion([invitation.toUid])], forDocument: groupRef)
        
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
