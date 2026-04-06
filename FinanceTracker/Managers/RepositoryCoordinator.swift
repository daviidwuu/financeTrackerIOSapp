import Foundation

/// Centralises the repetitive "start / stop listening" orchestration for all
/// Firestore repositories.  AppState holds repository instances; this type
/// operates on them so that the auth-state handler stays a single readable call.
struct RepositoryCoordinator {

    // Holds the in-flight gap-fill task so it can be cancelled on logout / re-login,
    // preventing cross-account transaction writes if the user switches accounts quickly.
    private static var gapFillTask: Task<Void, Never>?

    // MARK: - Public Interface

    /// Start real-time listeners on every repository for the given user.
    static func startAll(for userId: String, in appState: AppState) {
        // Cancel any prior gap-fill that may still be sleeping (e.g., rapid re-login)
        gapFillTask?.cancel()

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

        // After a short delay to allow the Firestore snapshots to arrive, run the
        // client-side gap-fill for any recurring transactions the backend may have missed.
        gapFillTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 s
            // Guard: bail out if the task was cancelled (logout) or the user changed
            guard !Task.isCancelled, appState.currentUserId == userId else { return }
            await appState.recurringRepo.processDueTransactions(
                userId: userId,
                transactionRepo: appState.transactionRepo
            )
        }
    }

    /// Stop all real-time listeners and clear premium state (called on logout or
    /// when the current user becomes anonymous).
    static func stopAll(in appState: AppState) {
        // Cancel the gap-fill before stopping repos so it can't write to a stale session
        gapFillTask?.cancel()
        gapFillTask = nil

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
