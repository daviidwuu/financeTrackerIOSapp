import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import Combine

/// Service for managing reward catalog and redemptions via Firestore + Cloud Functions.
/// Rewards are admin-managed in Firestore `rewards` collection.
/// Redemptions are processed server-side via Cloud Function for security.
class RewardService: ObservableObject {
    static let shared = RewardService()
    
    // MARK: - Published State
    @Published var rewards: [FirestoreModels.Reward] = []
    @Published var redemptions: [FirestoreModels.Redemption] = []
    @Published var isLoadingRewards = false
    @Published var isLoadingRedemptions = false
    @Published var isRedeeming = false
    @Published var errorMessage: String?
    @Published var lastRedemptionResult: RedemptionResult?
    
    private var db = Firestore.firestore()
    private var rewardsListener: ListenerRegistration?
    private var redemptionsListener: ListenerRegistration?
    
    struct RedemptionResult {
        let success: Bool
        let code: String?
        let message: String
    }
    
    private init() {}
    
    // MARK: - Fetch Rewards from Firestore
    
    func startListening(userRegion: String = "SG") {
        stopListening()
        isLoadingRewards = true
        
        // Listen to rewards collection, filtered by region
        rewardsListener = db.collection("rewards")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoadingRewards = false
                    
                    if let error = error {
                        DebugLogger.log("Error fetching rewards: \(error)")
                        self.errorMessage = "Failed to load rewards"
                        // Fall back to default rewards
                        self.rewards = Self.defaultRewards
                        return
                    }
                    
                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        // No rewards in Firestore yet — use defaults
                        self.rewards = Self.defaultRewards
                        return
                    }
                    
                    let allRewards = documents.compactMap { doc -> FirestoreModels.Reward? in
                        try? doc.data(as: FirestoreModels.Reward.self)
                    }
                    
                    // Filter by region: show rewards that match user's region or have no region (global)
                    self.rewards = allRewards.filter { reward in
                        guard let region = reward.region else { return true } // Global reward
                        return region == userRegion || region == "GLOBAL"
                    }
                    
                    // If no region-specific rewards, show defaults
                    if self.rewards.isEmpty {
                        self.rewards = Self.defaultRewards
                    }
                }
            }
    }
    
    func loadRedemptions(userId: String) {
        isLoadingRedemptions = true
        
        redemptionsListener = db.collection("users")
            .document(userId)
            .collection("redemptions")
            .order(by: "date", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoadingRedemptions = false
                    
                    if let error = error {
                        DebugLogger.log("Error fetching redemptions: \(error)")
                        return
                    }
                    
                    self.redemptions = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: FirestoreModels.Redemption.self)
                    } ?? []
                }
            }
    }
    
    func stopListening() {
        rewardsListener?.remove()
        redemptionsListener?.remove()
    }
    
    // MARK: - Redeem (uses fallback client-side until Cloud Function is deployed)
    
    func redeemReward(_ reward: FirestoreModels.Reward, currentPoints: Int, onResult: @escaping (RedemptionResult) -> Void) {
        guard currentPoints >= reward.cost else {
            onResult(RedemptionResult(success: false, code: nil, message: "Insufficient points"))
            return
        }
        
        guard !isRedeeming else {
            onResult(RedemptionResult(success: false, code: nil, message: "Please wait..."))
            return
        }
        
        isRedeeming = true
        errorMessage = nil
        
        // Use fallback client-side redemption (Cloud Function can be wired later)
        fallbackRedeem(reward: reward) { [weak self] result in
            DispatchQueue.main.async {
                self?.isRedeeming = false
                self?.lastRedemptionResult = result
                if result.success {
                    HapticManager.shared.success()
                }
                onResult(result)
            }
        }
    }
    
    // MARK: - Fallback (until Cloud Function is deployed)
    
    private func fallbackRedeem(reward: FirestoreModels.Reward, completion: @escaping (RedemptionResult) -> Void) {
        guard let userId = AppState.shared.currentUserId as String?, !userId.isEmpty else {
            completion(RedemptionResult(success: false, code: nil, message: "Not signed in"))
            return
        }
        
        let gamification = GamificationManager.shared
        guard gamification.points >= reward.cost else {
            completion(RedemptionResult(success: false, code: nil, message: "Insufficient points"))
            return
        }
        
        // Deduct points locally
        gamification.points -= reward.cost
        
        let code = generateCode()
        let redemption = FirestoreModels.Redemption(
            rewardId: reward.id,
            rewardTitle: reward.title,
            rewardIcon: reward.icon,
            cost: reward.cost,
            date: Date(),
            code: code,
            expiresAt: Calendar.current.date(byAdding: .day, value: reward.expiryDays ?? 30, to: Date()),
            status: "active",
            partnerName: reward.partnerName
        )
        
        redemptions.insert(redemption, at: 0)
        gamification.redemptions.insert(redemption, at: 0)
        
        // Persist atomically to Firestore
        let docRef = db.collection("users").document(userId)
        
        Task {
            do {
                _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                    let doc: DocumentSnapshot
                    do {
                        doc = try transaction.getDocument(docRef)
                    } catch let fetchError as NSError {
                        errorPointer?.pointee = fetchError
                        return nil
                    }
                    
                    let currentPoints = doc.data()?["points"] as? Int ?? 0
                    if currentPoints < reward.cost {
                        let error = NSError(domain: "Gamification", code: 400, userInfo: [NSLocalizedDescriptionKey: "Insufficient points"])
                        errorPointer?.pointee = error
                        return nil
                    }
                    
                    transaction.updateData(["points": currentPoints - reward.cost], forDocument: docRef)
                    
                    let redemptionRef = docRef.collection("redemptions").document(redemption.id)
                    do {
                        try transaction.setData(from: redemption, forDocument: redemptionRef)
                    } catch let encodeError as NSError {
                        errorPointer?.pointee = encodeError
                        return nil
                    }
                    return true
                }
                completion(RedemptionResult(success: true, code: code, message: "Reward redeemed!"))
            } catch {
                DebugLogger.log("Fallback redemption failed: \(error)")
                completion(RedemptionResult(success: false, code: nil, message: "Redemption failed. Please try again."))
            }
        }
    }
    
    private func generateCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in letters.randomElement()! })
    }
    
    // MARK: - Default Rewards (Singapore-focused)
    
    /// Used when Firestore rewards collection is empty or unavailable.
    /// These are realistic SG-relevant categories that will be replaced by real API data.
    static let defaultRewards: [FirestoreModels.Reward] = [
        FirestoreModels.Reward(
            id: "grab_voucher",
            title: "$5 Grab Voucher",
            cost: 500,
            icon: "car.fill",
            partnerName: "Grab",
            description: "$5 off your next Grab ride or GrabFood order in Singapore.",
            colorHex: "#00B14F",
            region: "SG",
            category: "transport",
            expiryDays: 30,
            isActive: true,
            rewardType: "voucher"
        ),
        FirestoreModels.Reward(
            id: "fairprice_voucher",
            title: "$5 FairPrice eVoucher",
            cost: 600,
            icon: "cart.fill",
            partnerName: "FairPrice",
            description: "$5 off groceries at any FairPrice outlet.",
            colorHex: "#E31837",
            region: "SG",
            category: "groceries",
            expiryDays: 60,
            isActive: true,
            rewardType: "voucher"
        ),
        FirestoreModels.Reward(
            id: "starbucks_treat",
            title: "Free Tall Drink",
            cost: 400,
            icon: "cup.and.saucer.fill",
            partnerName: "Starbucks SG",
            description: "Enjoy any Tall-sized handcrafted beverage at Starbucks Singapore.",
            colorHex: "#006241",
            region: "SG",
            category: "food",
            expiryDays: 14,
            isActive: true,
            rewardType: "voucher"
        ),
        FirestoreModels.Reward(
            id: "paypal_cashback",
            title: "$2 PayPal Credit",
            cost: 300,
            icon: "dollarsign.circle.fill",
            partnerName: "PayPal",
            description: "$2 SGD sent directly to your PayPal account. Real cash!",
            colorHex: "#003087",
            region: "GLOBAL",
            category: "cash",
            expiryDays: nil,
            isActive: true,
            rewardType: "paypal"
        ),
        FirestoreModels.Reward(
            id: "shopee_voucher",
            title: "$3 Shopee Credits",
            cost: 350,
            icon: "bag.fill",
            partnerName: "Shopee",
            description: "$3 Shopee credits for your next purchase. Works on any item!",
            colorHex: "#EE4D2D",
            region: "SG",
            category: "shopping",
            expiryDays: 30,
            isActive: true,
            rewardType: "voucher"
        )
    ]
}
