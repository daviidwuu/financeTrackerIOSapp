import Foundation

/// Centralises the repetitive "start / stop listening" orchestration for all
/// Firestore repositories.  AppState holds repository instances; this type
/// operates on them so that the auth-state handler stays a single readable call.
struct RepositoryCoordinator {

    // MARK: - Public Interface

    /// Start real-time listeners on every repository for the given user.
    static func startAll(for userId: String, in appState: AppState) {
        appState.transactionRepo.startListening(userId: userId)
        appState.budgetRepo.startListening(userId: userId)
        appState.recurringRepo.startListening(userId: userId)
        appState.savingGoalRepo.startListening(userId: userId)
        appState.requestRepo.startListening(userId: userId)
        appState.groupRepo.startListening(userId: userId)
        appState.friendRepo.startListening(userId: userId)
        appState.friendRequestRepo.startListening(userId: userId)
        appState.groupInvitationRepo.startListening(userId: userId)
        appState.guestRepo.startListening(userId: userId)
    }

    /// Stop all real-time listeners and clear premium state (called on logout or
    /// when the current user becomes anonymous).
    static func stopAll(in appState: AppState) {
        appState.transactionRepo.stopListening()
        appState.budgetRepo.stopListening()
        appState.recurringRepo.stopListening()
        appState.savingGoalRepo.stopListening()
        appState.requestRepo.stopListening()
        appState.groupRepo.stopListening()
        appState.friendRepo.stopListening()
        appState.friendRequestRepo.stopListening()
        appState.groupInvitationRepo.stopListening()
        appState.guestRepo.stopListening()
        appState.userPremiumRepo.clear()
    }
}
