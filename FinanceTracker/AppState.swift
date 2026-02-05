import SwiftUI
import Combine
import FirebaseAuth

import FirebaseFirestore

class AppState: ObservableObject {
    @Published var isUserLoggedIn = false
    @Published var currentUserId = ""
    @Published var hasCompletedOnboarding = false
    @Published var userName = ""
    @Published var userEmail = ""
    @Published var currentUserUsername = ""
    
    // Repositories
    @Published var groupRepo = GroupRepository()
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let firebaseManager = FirebaseManager.shared
    
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
                
                // Load user profile if authenticated and NOT anonymous
                if let userId = user?.uid, !isAnonymous {
                    Task {
                        await self?.loadUserProfile(userId: userId)
                    }
                    // Start listening to groups for this user
                    self?.groupRepo.startListening(userId: userId)
                } else {
                    // User logged out or is anonymous - stop group listener
                    self?.groupRepo.stopListening()
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
                    UserDefaults.standard.set(self.userSignupDate, forKey: "userSignupDate")
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
