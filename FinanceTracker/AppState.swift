import SwiftUI
import Combine
import AppIntents
import FirebaseAuth
import FirebaseFirestore

class AppState: ObservableObject {

    // MARK: - Domain State

    /// User identity and profile. AppState re-emits its changes so all
    /// existing @EnvironmentObject observers receive updates automatically.
    let profileState = ProfileState()

    // MARK: - Forwarded Profile Properties
    // All existing call sites (views, methods) continue to work unchanged.

    var isUserLoggedIn: Bool {
        get { profileState.isUserLoggedIn }
        set { profileState.isUserLoggedIn = newValue }
    }
    var currentUserId: String {
        get { profileState.currentUserId }
        set { profileState.currentUserId = newValue }
    }
    var hasCompletedOnboarding: Bool {
        get { profileState.hasCompletedOnboarding }
        set { profileState.hasCompletedOnboarding = newValue }
    }
    var userName: String {
        get { profileState.userName }
        set { profileState.userName = newValue }
    }
    var userEmail: String {
        get { profileState.userEmail }
        set { profileState.userEmail = newValue }
    }
    var currentUserUsername: String {
        get { profileState.currentUserUsername }
        set { profileState.currentUserUsername = newValue }
    }
    var userAvatarColor: String? {
        get { profileState.userAvatarColor }
        set { profileState.userAvatarColor = newValue }
    }
    var isLoadingAuth: Bool {
        get { profileState.isLoadingAuth }
        set { profileState.isLoadingAuth = newValue }
    }
    var isPremiumUser: Bool {
        get { profileState.isPremiumUser }
        set { profileState.isPremiumUser = newValue }
    }
    var streakCount: Int {
        get { profileState.streakCount }
        set { profileState.streakCount = newValue }
    }
    var hasSeenPostOnboardingGuide: Bool {
        get { profileState.hasSeenPostOnboardingGuide }
        set { profileState.hasSeenPostOnboardingGuide = newValue }
    }
    var userSignupDate: Date? {
        get { profileState.userSignupDate }
        set { profileState.userSignupDate = newValue }
    }
    var aggregatedIncome: Double {
        get { profileState.aggregatedIncome }
        set { profileState.aggregatedIncome = newValue }
    }
    var aggregatedExpense: Double {
        get { profileState.aggregatedExpense }
        set { profileState.aggregatedExpense = newValue }
    }

    // MARK: - Repositories
    // Kept here so RepositoryCoordinator can start/stop all listeners in one place.

    @Published var transactionRepo = TransactionRepository()
    @Published var budgetRepo = BudgetRepository()
    @Published var recurringRepo = RecurringTransactionRepository()
    @Published var savingGoalRepo = SavingGoalRepository()
    @Published var requestRepo = RequestRepository()
    @Published var groupRepo = GroupRepository()
    @Published var friendRepo = FriendRepository()
    @Published var friendRequestRepo = FriendRequestRepository()
    @Published var groupInvitationRepo = GroupInvitationRepository()
    @Published var guestRepo = GuestRepository()
    let userPremiumRepo = UserPremiumRepository()
    let userResolver = UserResolver()

    // MARK: - UI State
    // showProfile stays @Published here because HomeView uses $appState.showProfile
    // as a Binding — computed properties don't support $ projection.
    @Published var showProfile: Bool = false

    // MARK: - Navigation Forwarding

    var selectedTab: Int {
        get { AppNavigationState.shared.selectedTab }
        set { AppNavigationState.shared.selectedTab = newValue }
    }
    var shouldOpenCurrencySettings: Bool {
        get { AppNavigationState.shared.shouldOpenCurrencySettings }
        set { AppNavigationState.shared.shouldOpenCurrencySettings = newValue }
    }
    var showDailySummary: Bool {
        get { AppNavigationState.shared.showDailySummary }
        set { AppNavigationState.shared.showDailySummary = newValue }
    }
    var dailySummaryDate: Date? {
        get { AppNavigationState.shared.dailySummaryDate }
        set { AppNavigationState.shared.dailySummaryDate = newValue }
    }
    var showWeeklyReport: Bool {
        get { AppNavigationState.shared.showWeeklyReport }
        set { AppNavigationState.shared.showWeeklyReport = newValue }
    }

    // MARK: - Singleton

    static let shared = AppState()

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let firebaseManager = FirebaseManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        userResolver.configure(appState: self)

        // Re-emit ProfileState changes through AppState so all @EnvironmentObject
        // observers (which watch AppState) update whenever profile data changes.
        profileState.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let isAnonymous = user?.isAnonymous ?? false
                let hasUser = user != nil

                self.isUserLoggedIn = hasUser && !isAnonymous
                self.currentUserId = user?.uid ?? ""
                self.userEmail = user?.email ?? ""
                self.isLoadingAuth = false

                if let userId = user?.uid, !isAnonymous {
                    Task { await self.loadUserProfile(userId: userId) }
                    RepositoryCoordinator.startAll(for: userId, in: self)
                } else {
                    RepositoryCoordinator.stopAll(in: self)
                }
            }
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Streak

    private func updateStreak(userId: String) async {
        let calendar = Calendar.current
        do {
            let (currentStreak, lastVisit) = try await firebaseManager.getStreakData(userId: userId)
            let lastVisitDate = lastVisit ?? Date.distantPast

            if calendar.isDateInToday(lastVisitDate) {
                DispatchQueue.main.async { self.streakCount = max(1, currentStreak) }
            } else if calendar.isDateInYesterday(lastVisitDate) {
                let newStreak = currentStreak + 1
                DispatchQueue.main.async {
                    self.streakCount = newStreak
                    if newStreak >= 3 {
                        GamificationManager.shared.completeMission(id: "streak_starter")
                    }
                }
                try await firebaseManager.updateStreakData(userId: userId, streakCount: newStreak, lastVisitDate: Date())
            } else {
                DispatchQueue.main.async { self.streakCount = 1 }
                try await firebaseManager.updateStreakData(userId: userId, streakCount: 1, lastVisitDate: Date())
            }
        } catch {
            DebugLogger.log("Failed to update streak: \(error)")
        }
    }

    private func resetStreak() {
        DispatchQueue.main.async { self.streakCount = 1 }
    }

    // MARK: - Profile Loading

    private func loadUserProfile(userId: String) async {
        do {
            let profile = try await firebaseManager.getUserProfile(userId: userId)
            DispatchQueue.main.async {
                self.userName = profile["name"] as? String ?? ""
                self.currentUserUsername = profile["username"] as? String ?? ""
                self.userAvatarColor = profile["avatarColor"] as? String
                self.isPremiumUser = profile["isPremium"] as? Bool ?? false

                if let timestamp = profile["createdAt"] as? Timestamp {
                    self.userSignupDate = timestamp.dateValue()
                    let userKey = "userSignupDate_\(userId)"
                    UserDefaults.standard.set(self.userSignupDate, forKey: userKey)
                }

                self.aggregatedIncome = profile["aggregatedIncome"] as? Double ?? 0
                self.aggregatedExpense = profile["aggregatedExpense"] as? Double ?? 0

                if !self.userName.isEmpty {
                    UserDefaults.standard.set(self.userName, forKey: "user_name")
                }

                let guideKey = "hasSeenPostOnboardingGuide_\(userId)"
                self.hasSeenPostOnboardingGuide = UserDefaults.standard.bool(forKey: guideKey)
            }
            await updateStreak(userId: userId)
        } catch {
            DebugLogger.log("Failed to load user profile: \(error)")
        }
    }

    // MARK: - Auth Actions

    func login(userId: String, name: String, email: String) {
        self.userName = name
        UserDefaults.standard.set(name, forKey: "user_name")
        self.userEmail = email
        Task { await updateStreak(userId: userId) }
        FinanceTrackerShortcuts.updateAppShortcutParameters()
    }

    func logout() {
        do {
            try firebaseManager.signOut()
            resetStreak()
        } catch {
            DebugLogger.log("Logout error: \(error)")
        }
    }

    func completeOnboarding(userId: String, name: String, email: String, username: String) {
        self.hasCompletedOnboarding = true
        self.userName = name
        self.currentUserUsername = username
        UserDefaults.standard.set(name, forKey: "user_name")
        self.userEmail = email
        self.currentUserId = userId
        self.isUserLoggedIn = true
        Task { await updateStreak(userId: userId) }
        FinanceTrackerShortcuts.updateAppShortcutParameters()
        RepositoryCoordinator.startAll(for: userId, in: self)
    }

    func markPostOnboardingGuideAsSeen(userId: String) {
        let guideKey = "hasSeenPostOnboardingGuide_\(userId)"
        UserDefaults.standard.set(true, forKey: guideKey)
        hasSeenPostOnboardingGuide = true
    }
}
