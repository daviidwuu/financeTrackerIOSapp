import Foundation
import Combine
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

/// Centralized Firebase manager for authentication and database operations
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    let auth: Auth
    let db: Firestore
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var currentUserName: String?
    @Published var currentUserEmail: String?
    @Published var currentUserUsername: String?
    
    private init() {
        self.auth = Auth.auth()
        self.db = Firestore.firestore()
        
        // Listen to auth state changes
        let _ = auth.addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.isAuthenticated = user != nil
            
            if let user = user {
                Task {
                    // Fetch extended profile data (username)
                    try? await self?.fetchUserProfile(userId: user.uid)
                }
            }
        }
    }
    
    // MARK: - Authentication
    
    /// Check if a username is available
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        do {
            let snapshot = try await db.collection("users")
                .whereField("username", isEqualTo: username)
                .limit(to: 1)
                .getDocuments()
            
            return snapshot.documents.isEmpty
        } catch {
            DebugLogger.log("Error checking username availability: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Sign in anonymously to allow unauthenticated queries
    func signInAnonymously() async throws {
        if auth.currentUser == nil {
            try await auth.signInAnonymously()
            DebugLogger.log("Signed in anonymously for onboarding")
        }
    }
    
    /// Sign up a new user with email, password, and username
    func signUp(email: String, password: String, name: String, username: String) async throws -> User {
        // 1. Final check on username availability
        let isAvailable = try await checkUsernameAvailability(username)
        guard isAvailable else {
            throw NSError(domain: "Auth", code: 409, userInfo: [NSLocalizedDescriptionKey: "Username is already taken"])
        }
        
        // 2. Cleanup Anonymous User if exists
        if let currentUser = auth.currentUser, currentUser.isAnonymous {
            DebugLogger.log("Deleting anonymous user before creating new account")
            try? await currentUser.delete()
        }
        
        // 3. Create Auth User
        let result = try await auth.createUser(withEmail: email, password: password)
        let user = result.user
        
        // 3. Create user profile in Firestore
        try await createUserProfile(userId: user.uid, name: name, email: email, username: username)
        
        return user
    }
    
    /// Sign in existing user with email and password
    func signIn(email: String, password: String) async throws -> User {
        let result = try await auth.signIn(withEmail: email, password: password)
        return result.user
    }
    
    /// Sign out current user
    func signOut() throws {
        try auth.signOut()
    }
    
    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    /// Delete current user account
    func deleteUser() async throws {
        guard let user = auth.currentUser else { return }
        try await user.delete()
    }
    
    /// Update email
    func updateEmail(_ email: String) async throws {
        guard let user = auth.currentUser else { return }
        try await user.sendEmailVerification(beforeUpdatingEmail: email)
        // Update Firestore
        try await updateUserProfile(userId: user.uid, data: ["email": email])
    }
    
    // MARK: - User Profile
    
    /// Create user profile document in Firestore
    private func createUserProfile(userId: String, name: String, email: String, username: String) async throws {
        let profileData: [String: Any] = [
            "name": name,
            "email": email,
            "username": username,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("users").document(userId).setData(profileData)
        
        await MainActor.run {
            self.currentUserName = name
            self.currentUserEmail = email
            self.currentUserUsername = username
        }
    }
    
    /// Get user profile from Firestore
    func getUserProfile(userId: String) async throws -> [String: Any] {
        let document = try await db.collection("users").document(userId).getDocument()
        guard let data = document.data() else {
            throw NSError(domain: "FirebaseManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }
        return data
    }
    
    /// Fetch and cache current user profile
    func fetchUserProfile(userId: String) async throws {
        let data = try await getUserProfile(userId: userId)
        await MainActor.run {
            self.currentUserName = data["name"] as? String
            self.currentUserEmail = data["email"] as? String
            self.currentUserUsername = data["username"] as? String
        }
    }
    
    /// Update user profile
    func updateUserProfile(userId: String, data: [String: Any]) async throws {
        try await db.collection("users").document(userId).updateData(data)
        // Refresh local cache if needed
        if let newName = data["name"] as? String {
            await MainActor.run { self.currentUserName = newName }
        }
        if let newUsername = data["username"] as? String {
            await MainActor.run { self.currentUserUsername = newUsername }
        }
    }
    
    // MARK: - Streak Management
    
    /// Get user's streak data (count and last visit date)
    func getStreakData(userId: String) async throws -> (streakCount: Int, lastVisitDate: Date?) {
        let document = try await db.collection("users").document(userId).getDocument()
        guard let data = document.data() else {
            return (1, nil) // Default for new users
        }
        
        let streakCount = data["streakCount"] as? Int ?? 1
        let lastVisitTimestamp = data["lastVisitDate"] as? Timestamp
        let lastVisitDate = lastVisitTimestamp?.dateValue()
        
        return (streakCount, lastVisitDate)
    }
    
    /// Update user's streak data in Firestore
    func updateStreakData(userId: String, streakCount: Int, lastVisitDate: Date) async throws {
        let data: [String: Any] = [
            "streakCount": streakCount,
            "lastVisitDate": Timestamp(date: lastVisitDate)
        ]
        try await db.collection("users").document(userId).setData(data, merge: true)
    }
}
