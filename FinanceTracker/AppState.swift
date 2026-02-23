import SwiftUI
import Combine
import FirebaseAuth

import FirebaseFirestore

class AppState: ObservableObject {
    @Published var isUserLoggedIn = false
    @Published var currentUserId = ""
    @Published var hasCompletedOnboarding = false
    @Published var userName = UserDefaults.standard.string(forKey: "user_name") ?? ""
    @Published var userEmail = ""
    @Published var currentUserUsername = ""
    @Published var isLoadingAuth = true // Track initial auth check
    @Published var isPremiumUser = false // ✅ NEW: Tracks premium status
    
    // Repositories
    // Repositories
    @Published var transactionRepo = TransactionRepository()
    @Published var budgetRepo = BudgetRepository()
    @Published var recurringRepo = RecurringTransactionRepository()
    @Published var savingGoalRepo = SavingGoalRepository() // Also centralizing this as it's used in WalletView
    @Published var requestRepo = RequestRepository() // Centralizing RequestRepository
    @Published var groupRepo = GroupRepository()
    @Published var friendRepo = FriendRepository() // ✅ NEW: Global friendship cache
    @Published var friendRequestRepo = FriendRequestRepository() // ✅ NEW: For incoming/outgoing requests
    @Published var groupInvitationRepo = GroupInvitationRepository() // ✅ NEW: For group invites
    @Published var guestRepo = GuestRepository() // ✅ NEW: For guests
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let firebaseManager = FirebaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var streakCount = 1
    @Published var hasSeenPostOnboardingGuide = false
    @Published var showWeeklyReport = false
    
    // Deep Link State
    @Published var showDailySummary = false
    @Published var dailySummaryDate: Date?
    @Published var userSignupDate: Date?
    
    // Navigation State
    @Published var showProfile = false
    @Published var shouldOpenCurrencySettings = false
    @Published var selectedTab = 0 // 0: Home, 1: Wallet, 2: Friends, etc.
    
    static let shared = AppState()
    
    private init() {
        // Streak will be initialized when user logs in
        
        // Listen to Firebase auth state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _,  user in
            DispatchQueue.main.async {
                let isAnonymous = user?.isAnonymous ?? false
                let hasUser = user != nil
                
                // Only consider the user "logged in" for UI purposes if they are not anonymous
                self?.isUserLoggedIn = hasUser && !isAnonymous
                self?.currentUserId = user?.uid ?? ""
                self?.userEmail = user?.email ?? ""
                self?.isLoadingAuth = false // Auth check complete
                
                // Load user profile if authenticated and NOT anonymous
                if let userId = user?.uid, !isAnonymous {
                    Task {
                        await self?.loadUserProfile(userId: userId)
                    }
                    // Start listening to groups for this user
                    self?.transactionRepo.startListening(userId: userId)
                    self?.budgetRepo.startListening(userId: userId)
                    self?.recurringRepo.startListening(userId: userId)
                    self?.savingGoalRepo.startListening(userId: userId)
                    self?.requestRepo.startListening(userId: userId)
                    self?.groupRepo.startListening(userId: userId)
                    self?.friendRepo.startListening(userId: userId) // ✅ NEW
                    self?.friendRequestRepo.startListening(userId: userId) // ✅ NEW
                    self?.groupInvitationRepo.startListening(userId: userId) // ✅ NEW
                    self?.guestRepo.startListening(userId: userId) // ✅ NEW
                } else {
                    // User logged out or is anonymous - stop group listener
                    self?.transactionRepo.stopListening()
                    self?.budgetRepo.stopListening()
                    self?.recurringRepo.stopListening()
                    self?.savingGoalRepo.stopListening()
                    self?.requestRepo.stopListening()
                    self?.groupRepo.stopListening()
                    self?.friendRepo.stopListening()
                    self?.friendRequestRepo.stopListening()
                    self?.groupInvitationRepo.stopListening()
                    self?.guestRepo.stopListening()
                }
            }
        }
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    private func updateStreak(userId: String) async {
        let calendar = Calendar.current
        
        do {
            // Fetch current streak data from Firebase
            let (currentStreak, lastVisit) = try await firebaseManager.getStreakData(userId: userId)
            let lastVisitDate = lastVisit ?? Date.distantPast
            
            if calendar.isDateInToday(lastVisitDate) {
                // Already visited today, streak remains same
                DispatchQueue.main.async {
                    self.streakCount = max(1, currentStreak)
                }
            } else if calendar.isDateInYesterday(lastVisitDate) {
                // Visited yesterday, increment streak
                let newStreak = currentStreak + 1
                DispatchQueue.main.async {
                    self.streakCount = newStreak
                    
                    // Gamification
                    if newStreak >= 3 {
                        GamificationManager.shared.completeMission(id: "streak_starter")
                    }
                }
                try await firebaseManager.updateStreakData(userId: userId, streakCount: newStreak, lastVisitDate: Date())
            } else {
                // Missed a day or first time, reset to 1
                DispatchQueue.main.async {
                    self.streakCount = 1
                }
                try await firebaseManager.updateStreakData(userId: userId, streakCount: 1, lastVisitDate: Date())
            }
        } catch {
            DebugLogger.log("Failed to update streak: \(error)")
        }
    }
    
    private func resetStreak() {
        DispatchQueue.main.async {
            self.streakCount = 1
        }
    }
    
    private func loadUserProfile(userId: String) async {
        do {
            let profile = try await firebaseManager.getUserProfile(userId: userId)
            DispatchQueue.main.async {
                self.userName = profile["name"] as? String ?? ""
                self.currentUserUsername = profile["username"] as? String ?? ""
                
                // Parse signup date
                if let timestamp = profile["createdAt"] as? Timestamp {
                    self.userSignupDate = timestamp.dateValue()
                    // Cache to UserDefaults for offline/fallback use
                    let userKey = "userSignupDate_\(userId)"
                    UserDefaults.standard.set(self.userSignupDate, forKey: userKey)
                }
                
                // Cache username for offline/fast access
                if !self.userName.isEmpty {
                    UserDefaults.standard.set(self.userName, forKey: "user_name")
                }
                
                // Load post-onboarding guide status per user
                let guideKey = "hasSeenPostOnboardingGuide_\(userId)"
                self.hasSeenPostOnboardingGuide = UserDefaults.standard.bool(forKey: guideKey)
            }
            // Load and update streak for this user
            await updateStreak(userId: userId)
        } catch {
            DebugLogger.log("Failed to load user profile: \(error)")
        }
    }
    
    func login(userId: String, name: String, email: String) {
        // Firebase auth state listener will handle the update
        self.userName = name
        UserDefaults.standard.set(name, forKey: "user_name")
        self.userEmail = email
        Task {
            await updateStreak(userId: userId)
        }
    }
    
    func logout() {
        do {
            try firebaseManager.signOut()
            // Reset streak when logging out
            resetStreak()
            // Firebase auth state listener will handle clearing state
        } catch {
            DebugLogger.log("Logout error: \(error)")
        }
    }
    
    func completeOnboarding(userId: String, name: String, email: String) {
        self.hasCompletedOnboarding = true
        self.userName = name
        UserDefaults.standard.set(name, forKey: "user_name")
        self.userEmail = email
        Task {
            await updateStreak(userId: userId)
        }
        // User is already authenticated via Firebase Auth
    }
    
    func markPostOnboardingGuideAsSeen(userId: String) {
        let guideKey = "hasSeenPostOnboardingGuide_\(userId)"
        UserDefaults.standard.set(true, forKey: guideKey)
        hasSeenPostOnboardingGuide = true
    }
}
