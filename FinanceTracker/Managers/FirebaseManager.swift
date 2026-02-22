import Foundation
import Combine
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

/// Centralized Firebase manager for authentication and database operations
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    private let auth: Auth
    private let db: Firestore
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var currentUserName: String?
    @Published var currentUserEmail: String?
    @Published var currentUserUsername: String?
    
    private init() {
        self.auth = Auth.auth()
        
        // Configure Firestore with persistence enabled
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        
        let db = Firestore.firestore()
        db.settings = settings
        self.db = db
        
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
        if username.contains(" ") {
            return false
        }
        do {
            let doc = try await db.collection("usernames").document(username.lowercased()).getDocument()
            if doc.exists {
                return false
            }
            
            // Fallback for existing users who might not be in the usernames collection
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
        if username.contains(" ") {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Username cannot contain spaces"])
        }
        let isAvailable = try await checkUsernameAvailability(username)
        guard isAvailable else {
            throw NSError(domain: "Auth", code: 409, userInfo: [NSLocalizedDescriptionKey: "Username is already taken"])
        }
        
        let user: User
        
        // 2. Safely Link or Create
        if let currentUser = auth.currentUser, currentUser.isAnonymous {
            // LINK CURRENT ANONYMOUS USER
            DebugLogger.log("Linking anonymous user to new credential")
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            do {
                let result = try await currentUser.link(with: credential)
                user = result.user
            } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                // Fallback if link fails due to existing account
                throw error
            }
        } else {
            // CREATE NEW USER (No anonymous session active)
            let result = try await auth.createUser(withEmail: email, password: password)
            user = result.user
        }
        
        // 3. Register username atomically
        let usernameRef = db.collection("usernames").document(username.lowercased())
        do {
            _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let doc: DocumentSnapshot
                do {
                    doc = try transaction.getDocument(usernameRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                if doc.exists {
                    let error = NSError(domain: "Auth", code: 409, userInfo: [NSLocalizedDescriptionKey: "Username is already taken"])
                    errorPointer?.pointee = error
                    return nil
                }
                
                transaction.setData(["uid": user.uid, "createdAt": FieldValue.serverTimestamp()], forDocument: usernameRef)
                return true
            }
        } catch {
            // If username registration fails, clean up the auth user
            try? await user.delete()
            throw error
        }
        
        // 4. Create user profile in Firestore
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
        let userId = user.uid
        
        // 1. Client-side best-effort deletion of user data
        let batch = db.batch()
        let userRef = db.collection("users").document(userId)
        batch.deleteDocument(userRef)
        
        if let transactions = try? await userRef.collection("transactions").limit(to: 500).getDocuments() {
            for doc in transactions.documents {
                batch.deleteDocument(doc.reference)
            }
        }
        
        if let budgets = try? await userRef.collection("budgets").limit(to: 500).getDocuments() {
            for doc in budgets.documents {
                batch.deleteDocument(doc.reference)
            }
        }
        
        if let recurring = try? await userRef.collection("recurring_transactions").limit(to: 500).getDocuments() {
            for doc in recurring.documents {
                batch.deleteDocument(doc.reference)
            }
        }
        
        if let currentUsername = currentUserUsername {
            let usernameRef = db.collection("usernames").document(currentUsername.lowercased())
            batch.deleteDocument(usernameRef)
        }
        
        do {
            try await batch.commit()
            DebugLogger.log("Successfully deleted user data from Firestore")
        } catch {
            DebugLogger.log("Failed to clean up user data before deletion: \(error)")
        }
        
        // 2. Delete the auth user
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
    
    /// Fetch and cache current user profile (Cache-first strategy)
    func fetchUserProfile(userId: String) async throws {
        // 1. Try to fetch from cache first for instant load
        do {
            let cachedDoc = try await db.collection("users").document(userId).getDocument(source: .cache)
            if let data = cachedDoc.data() {
                self.updateLocalUser(data: data)
                DebugLogger.log("Loaded user profile from cache")
            }
        } catch {
            // Cache miss is expected on first run
            DebugLogger.log("Cache miss for user profile: \(error.localizedDescription)")
        }
        
        // 2. Fetch from server to ensure fresh data (graceful fallback if offline)
        // FIX #15: Don't throw on server failure if cache data was already loaded
        do {
            let serverDoc = try await db.collection("users").document(userId).getDocument(source: .server)
            if let data = serverDoc.data() {
                self.updateLocalUser(data: data)
                DebugLogger.log("Refreshed user profile from server")
            }
        } catch {
            // If we already loaded from cache, this is acceptable (offline mode)
            if self.currentUserName != nil {
                DebugLogger.log("Server refresh failed (offline?), using cached profile: \(error.localizedDescription)")
            } else {
                // No cache AND no server — propagate the error
                throw error
            }
        }
    }
    
    @MainActor
    private func updateLocalUser(data: [String: Any]) {
        self.currentUserName = data["name"] as? String
        self.currentUserEmail = data["email"] as? String
        self.currentUserUsername = data["username"] as? String
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
    // MARK: - Notification
    
    func updateFCMToken(userId: String, token: String) async throws {
       try await db.collection("users").document(userId).setData(["fcmToken": token], merge: true)
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
