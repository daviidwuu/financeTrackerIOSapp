import Foundation
import Combine

/// Manages AI-powered dynamic content and personalized financial motivations
class AIContentManager: ObservableObject {
    static let shared = AIContentManager()
    
    @Published var dailyTip: String?
    @Published var isLoading = false
    
    private let userDefaults = UserDefaults.standard
    private let lastTipKey = "last_ai_tip"
    private let lastFetchDateKey = "last_ai_tip_fetch_date"
    
    private init() {
        loadCachedTip()
    }
    
    /// Fetches a new personalized tip from the AI backend
    func fetchFreshMotivation() async {
        // Only fetch once per day to keep it fresh but not overwhelming
        if let lastFetch = userDefaults.object(forKey: lastFetchDateKey) as? Date,
           Calendar.current.isDateInToday(lastFetch) {
            return
        }
        
        await MainActor.run { isLoading = true }
        
        // Simulating an AI backend call. 
        // In a real implementation, this would call a Firebase Function that wraps Vertex AI or OpenAI.
        // For now, we fetch from a curated set of high-quality AI-style tips via Remote Config (implemented in FirebaseManager)
        
        do {
            // Wait for Remote Config to be ready
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay simulation
            
            let tips = FirebaseManager.shared.getRemoteMotivationalTips()
            if let randomTip = tips.randomElement() {
                await MainActor.run {
                    self.dailyTip = randomTip
                    self.isLoading = false
                    
                    // Cache it
                    userDefaults.set(randomTip, forKey: lastTipKey)
                    userDefaults.set(Date(), forKey: lastFetchDateKey)
                }
            }
        } catch {
            await MainActor.run { isLoading = false }
            DebugLogger.log("Failed to fetch AI motivation: \(error.localizedDescription)")
        }
    }
    
    private func loadCachedTip() {
        self.dailyTip = userDefaults.string(forKey: lastTipKey)
    }
}
