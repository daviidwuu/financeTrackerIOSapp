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
    
    private init() {
        self.auth = Auth.auth()
        self.db = Firestore.firestore()
        
        // Listen to auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.isAuthenticated = user != nil
        }
    }
    
    // MARK: - Authentication
    
    /// Sign up a new user with email and password
    func signUp(email: String, password: String, name: String) async throws -> User {
        let result = try await auth.createUser(withEmail: email, password: password)
        let user = result.user
        
        // Create user profile in Firestore
        try await createUserProfile(userId: user.uid, name: name, email: email)
        
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
        try await user.updateEmail(to: email)
        // Update Firestore
        try await updateUserProfile(userId: user.uid, data: ["email": email])
    }
    
    // MARK: - User Profile
    
    /// Create user profile document in Firestore
    private func createUserProfile(userId: String, name: String, email: String) async throws {
        let profileData: [String: Any] = [
            "name": name,
            "email": email,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("users").document(userId).setData(profileData)
    }
    
    /// Get user profile from Firestore
    func getUserProfile(userId: String) async throws -> [String: Any] {
        let document = try await db.collection("users").document(userId).getDocument()
        guard let data = document.data() else {
            throw NSError(domain: "FirebaseManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }
        return data
    }
    
    /// Update user profile
    func updateUserProfile(userId: String, data: [String: Any]) async throws {
        try await db.collection("users").document(userId).updateData(data)
    }
}
