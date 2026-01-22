import SwiftUI
import Combine
import FirebaseAuth

class AppState: ObservableObject {
    @Published var isUserLoggedIn = false
    @Published var currentUserId = ""
    @Published var hasCompletedOnboarding = false
    @Published var userName = ""
    @Published var userEmail = ""
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let firebaseManager = FirebaseManager.shared
    
    @Published var streakCount = 1
    
    private let streakKey = "userStreakCount"
    private let lastVisitDateKey = "lastVisitDate"
    
    static let shared = AppState()
    
    private init() {
        // Initialize streak
        updateStreak()
        
        // Listen to Firebase auth state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _,  user in
            DispatchQueue.main.async {
                self?.isUserLoggedIn = user != nil
                self?.currentUserId = user?.uid ?? ""
                self?.userEmail = user?.email ?? ""
                
                // Load user profile if authenticated
                if let userId = user?.uid {
                    Task {
                        await self?.loadUserProfile(userId: userId)
                    }
                }
            }
        }
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    private func updateStreak() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        
        let lastVisit = defaults.object(forKey: lastVisitDateKey) as? Date ?? Date.distantPast
        let currentStreak = defaults.integer(forKey: streakKey)
        
        if calendar.isDateInToday(lastVisit) {
            // Already visited today, streak remains same
            self.streakCount = max(1, currentStreak)
        } else if calendar.isDateInYesterday(lastVisit) {
            // Visited yesterday, increment streak
            let newStreak = currentStreak + 1
            self.streakCount = newStreak
            defaults.set(newStreak, forKey: streakKey)
            defaults.set(Date(), forKey: lastVisitDateKey)
        } else {
            // Missed a day (or first time), reset to 1
            // Check if it is the very first time launch (distantPast)
            if lastVisit == Date.distantPast {
                 // First launch ever
                 self.streakCount = 1
                 defaults.set(1, forKey: streakKey)
                 defaults.set(Date(), forKey: lastVisitDateKey)
            } else {
                // Broken streak
                self.streakCount = 1
                defaults.set(1, forKey: streakKey)
                defaults.set(Date(), forKey: lastVisitDateKey)
            }
        }
    }
    
    private func loadUserProfile(userId: String) async {
        do {
            let profile = try await firebaseManager.getUserProfile(userId: userId)
            DispatchQueue.main.async {
                self.userName = profile["name"] as? String ?? ""
            }
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }
    
    func login(userId: String, name: String, email: String) {
        // Firebase auth state listener will handle the update
        self.userName = name
        self.userEmail = email
        updateStreak()
    }
    
    func logout() {
        do {
            try firebaseManager.signOut()
            // Firebase auth state listener will handle clearing state
        } catch {
            print("Logout error: \(error)")
        }
    }
    
    func completeOnboarding(userId: String, name: String, email: String) {
        self.hasCompletedOnboarding = true
        self.userName = name
        self.userEmail = email
        updateStreak()
        // User is already authenticated via Firebase Auth
    }
}
