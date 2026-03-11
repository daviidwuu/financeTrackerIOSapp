import Foundation
import Combine
import FirebaseFirestore

final class UserPremiumRepository: ObservableObject {
    @Published private(set) var premiumByUserId: [String: Bool] = [:]
    @Published private(set) var badgeTypeByUserId: [String: PremiumBadgeType] = [:]

    private let db = Firestore.firestore()
    private var inFlight: Set<String> = []

    func isPremium(userId: String) -> Bool? {
        premiumByUserId[userId]
    }

    func badgeType(userId: String) -> PremiumBadgeType? {
        badgeTypeByUserId[userId]
    }
    
    func prefetch(userIds: [String]) {
        let unique = Array(Set(userIds.filter { !$0.isEmpty }))
        let missing = unique.filter { premiumByUserId[$0] == nil && !inFlight.contains($0) }
        guard !missing.isEmpty else { return }
        
        missing.forEach { inFlight.insert($0) }
        
        Task {
            let chunkSize = 30
            let chunks = stride(from: 0, to: missing.count, by: chunkSize).map {
                Array(missing[$0..<min($0 + chunkSize, missing.count)])
            }
            
            var premiumResults: [String: Bool] = [:]
            var badgeResults: [String: PremiumBadgeType] = [:]

            for chunk in chunks {
                do {
                    let snapshot = try await db.collection("users")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()

                    for doc in snapshot.documents {
                        let data = doc.data()
                        let isPremium = data["isPremium"] as? Bool ?? false
                        premiumResults[doc.documentID] = isPremium
                        if let badgeRaw = data["badgeType"] as? String,
                           let badge = PremiumBadgeType(rawValue: badgeRaw) {
                            badgeResults[doc.documentID] = badge
                        }
                    }
                } catch {
                    DebugLogger.log("Failed to fetch premium status: \(error)")
                }
            }

            await MainActor.run {
                for id in missing {
                    self.inFlight.remove(id)
                }
                self.premiumByUserId.merge(premiumResults) { _, new in new }
                self.badgeTypeByUserId.merge(badgeResults) { _, new in new }
            }
        }
    }
    
    func setPremium(userId: String, isPremium: Bool, badgeType: PremiumBadgeType? = nil) {
        guard !userId.isEmpty else { return }
        premiumByUserId[userId] = isPremium
        if let badgeType {
            badgeTypeByUserId[userId] = badgeType
        }
    }

    func clear() {
        premiumByUserId = [:]
        badgeTypeByUserId = [:]
        inFlight = []
    }
}
