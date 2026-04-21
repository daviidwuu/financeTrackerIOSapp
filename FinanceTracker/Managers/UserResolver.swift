import Foundation
import FirebaseFirestore

/// Centralized utility for resolving user display names from UIDs.
/// Eliminates duplicate `resolveName` functions scattered across views.
/// Uses cached repositories (FriendRepository, GuestRepository) for O(1) lookups.
class UserResolver {
    
    private weak var appState: AppState?
    
    init(appState: AppState? = nil) {
        self.appState = appState
    }
    
    func configure(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Primary Resolution
    
    /// Resolves a display name for the given UID.
    /// Priority: "You" → FriendRepo → GuestRepo → fallbackName → "Unknown"
    func resolveName(for uid: String, fallbackName: String? = nil) -> String {
        guard let appState = appState else {
            return fallbackName ?? "Unknown"
        }
        
        // 1. Current user
        if uid == appState.currentUserId {
            return "You"
        }
        
        // 2. Friend cache (O(1) via array scan — could be optimized to dict later)
        if let friend = appState.friendRepo.friends.first(where: { $0.id == uid }) {
            return friend.name
        }
        
        // 3. Guest cache
        if let guest = appState.guestRepo.guests.first(where: { $0.id == uid }) {
            return guest.name
        }
        
        // 4. Fallback to denormalized name if provided
        if let name = fallbackName, !name.isEmpty, name != "Unknown" {
            return name
        }
        
        return "Unknown"
    }
    
    /// Resolves a display name, also checking group memberNames for additional context.
    func resolveName(for uid: String, fallbackName: String? = nil, groupMemberNames: [String: String]?) -> String {
        let resolved = resolveName(for: uid, fallbackName: fallbackName)
        if resolved != "Unknown" { return resolved }
        
        // Check group member names as a secondary fallback
        if let memberName = groupMemberNames?[uid], !memberName.isEmpty {
            return memberName
        }
        
        return "Unknown"
    }

    /// Resolves an avatar color for the given UID.
    /// Priority: "You" -> FriendRepo -> GuestRepo
    func resolveAvatarColor(for uid: String) -> String? {
        guard let appState = appState else { return nil }
        
        // 1. Current user
        if uid == appState.currentUserId {
            return appState.userAvatarColor
        }
        
        // 2. Friend cache
        if let friend = appState.friendRepo.friends.first(where: { $0.id == uid }) {
            return friend.avatarColor
        }
        
        // 3. Guest cache
        if let guest = appState.guestRepo.guests.first(where: { $0.id == uid }) {
            return guest.avatarColor
        }
        
        return nil
    }
    
    /// Resolves the current user's own display name.
    func currentUserName() -> String {
        guard let appState = appState else {
            return UserDefaults.standard.string(forKey: "user_name") ?? "You"
        }
        return !appState.userName.isEmpty ? appState.userName : (UserDefaults.standard.string(forKey: "user_name") ?? "You")
    }
}
