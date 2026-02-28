import Foundation

final class WhatsNewManager {
    static let shared = WhatsNewManager()
    
    private let lastSeenVersionKey = "whatsNew_lastSeenVersion"
    
    private init() {}
    
    func shouldShow() -> Bool {
        let current = AppConfig.shortVersion
        let lastSeen = UserDefaults.standard.string(forKey: lastSeenVersionKey)
        return lastSeen != current
    }
    
    func markSeen() {
        UserDefaults.standard.set(AppConfig.shortVersion, forKey: lastSeenVersionKey)
    }
}
