import Foundation
import Combine

/// Domain-scoped state for the authenticated user's identity and profile data.
/// AppState holds this and re-emits its changes so all existing @EnvironmentObject
/// observers continue to work without modification.
final class ProfileState: ObservableObject {
    @Published var isUserLoggedIn: Bool = false
    @Published var currentUserId: String = ""
    @Published var hasCompletedOnboarding: Bool = false
    @Published var userName: String = UserDefaults.standard.string(forKey: "user_name") ?? ""
    @Published var userEmail: String = ""
    @Published var currentUserUsername: String = ""
    @Published var userAvatarColor: String?
    @Published var isLoadingAuth: Bool = true
    @Published var isPremiumUser: Bool = false
    @Published var streakCount: Int = 1
    @Published var hasSeenPostOnboardingGuide: Bool = false
    @Published var userSignupDate: Date?
    @Published var aggregatedIncome: Double = 0
    @Published var aggregatedExpense: Double = 0
}
