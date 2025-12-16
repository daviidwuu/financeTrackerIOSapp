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
    
    static let shared = AppState()
    
    private init() {
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
        // User is already authenticated via Firebase Auth
    }
}
