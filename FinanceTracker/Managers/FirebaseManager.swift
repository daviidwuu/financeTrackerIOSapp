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
        // FIX #23: Trim whitespace and reject empty/whitespace-only input
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.contains(" ") {
            return false
        }
        do {
            let doc = try await db.collection("usernames").document(username.lowercased()).getDocument()
            if doc.exists {
                // Return true if the taken username belongs to the current user
                if let ownerUid = doc.data()?["uid"] as? String, ownerUid == auth.currentUser?.uid {
                    return true
                }
                return false
            }
            
            // Fallback for existing users who might not be in the usernames collection
            let snapshot = try await db.collection("users")
                .whereField("username", isEqualTo: username)
                .limit(to: 1)
                .getDocuments()
            
            if !snapshot.documents.isEmpty {
                 if snapshot.documents.first?.documentID == auth.currentUser?.uid {
                     return true
                 }
                 return false
            }
            return true
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
        let userRef = db.collection("users").document(userId)

        // Delete all documents in each subcollection (paginated to handle >500 docs)
        let subcollections = ["transactions", "budgets", "recurring_transactions", "recurringTransactions", "savingGoals", "friends"]
        for subcollection in subcollections {
            try? await deleteAllDocuments(in: userRef.collection(subcollection))
        }

        // Delete split requests created by this user
        try? await deleteAllMatchingDocuments(
            in: db.collection("split_requests"),
            field: "fromUid",
            value: userId
        )

        // Delete username reservation and user document
        let batch = db.batch()
        batch.deleteDocument(userRef)

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
    
    // MARK: - Paginated Deletion Helpers

    /// Deletes all documents in a collection reference, paginating in batches of 500.
    private func deleteAllDocuments(in collectionRef: CollectionReference) async throws {
        var hasMore = true
        while hasMore {
            let snapshot = try await collectionRef.limit(to: 500).getDocuments()
            if snapshot.documents.isEmpty { hasMore = false; break }
            let batch = db.batch()
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }
    }

    /// Deletes all documents in a collection where a field matches a value, paginating in batches of 500.
    private func deleteAllMatchingDocuments(in collectionRef: CollectionReference, field: String, value: String) async throws {
        var hasMore = true
        while hasMore {
            let snapshot = try await collectionRef
                .whereField(field, isEqualTo: value)
                .limit(to: 500)
                .getDocuments()
            if snapshot.documents.isEmpty { hasMore = false; break }
            let batch = db.batch()
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }
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
            "isPremium": false,
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
    
    /// Update user's username atomically across `users` and `usernames` collections
    func updateUsername(userId: String, oldUsername: String?, newUsername: String) async throws {
        if newUsername.contains(" ") {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Username cannot contain spaces"])
        }
        
        let newUsernameRef = db.collection("usernames").document(newUsername.lowercased())
        let userRef = db.collection("users").document(userId)
        
        // 1. Transaction to update username atomically
        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let doc: DocumentSnapshot
            do {
                doc = try transaction.getDocument(newUsernameRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            if doc.exists {
                let error = NSError(domain: "Auth", code: 409, userInfo: [NSLocalizedDescriptionKey: "Username is already taken"])
                errorPointer?.pointee = error
                return nil
            }
            
            // 2. Set the new username document
            transaction.setData(["uid": userId, "createdAt": FieldValue.serverTimestamp()], forDocument: newUsernameRef)
            
            // 3. Delete the old username document if it exists AND is fundamentally different (ignoring case is fine, but if paths are same, don't delete)
            if let old = oldUsername {
                let oldUsernameRef = self.db.collection("usernames").document(old.lowercased())
                if oldUsernameRef.path != newUsernameRef.path {
                    transaction.deleteDocument(oldUsernameRef)
                }
            }
            
            // 4. Update the user document
            transaction.updateData(["username": newUsername], forDocument: userRef)
            
            return true
        }
        
        // Refresh local cache
        await MainActor.run { self.currentUserUsername = newUsername }
    }
    
    /// Update user profile
    func updateUserProfile(userId: String, data: [String: Any]) async throws {
        var mutableData = data
        // Prevent accidental misuse for username updates
        if mutableData.keys.contains("username") {
            DebugLogger.log("Warning: updateUserProfile should not be used for username updates. Use updateUsername instead.")
            mutableData.removeValue(forKey: "username")
        }
        
        guard !mutableData.isEmpty else { return }
        
        try await db.collection("users").document(userId).updateData(mutableData)
        // Refresh local cache if needed
        if let newName = mutableData["name"] as? String {
            await MainActor.run { self.currentUserName = newName }

            // FIX #15: Sync denormalized names in pending split_requests
            // Wrapped in do/catch to prevent collection group query permission errors
            // from failing the entire profile update
            do {
                // Update fromName where this user is the sender
                let fromSnap = try await db.collectionGroup("split_requests")
                    .whereField("fromUid", isEqualTo: userId)
                    .getDocuments()
                for doc in fromSnap.documents {
                    try? await doc.reference.updateData(["fromName": newName])
                }
                // Update toName where this user is the receiver
                let toSnap = try await db.collectionGroup("split_requests")
                    .whereField("toUid", isEqualTo: userId)
                    .getDocuments()
                for doc in toSnap.documents {
                    try? await doc.reference.updateData(["toName": newName])
                }
            } catch {
                DebugLogger.log("Warning: Failed to sync name in split_requests: \(error.localizedDescription)")
            }
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
