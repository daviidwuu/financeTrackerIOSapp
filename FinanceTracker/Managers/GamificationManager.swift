import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

class GamificationManager: ObservableObject {
    static let shared = GamificationManager()
    
    // MARK: - Published State
    @Published var points: Int = 0
    @Published var completedMissionIds: Set<String> = []
    @Published var currentPhase: Int = 1
    @Published var showCelebration: Bool = false
    @Published var latestCompletedMission: Mission?
    
    private var db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Mission Definitions
    
    struct Mission: Identifiable, Equatable {
        let id: String
        let title: String
        let description: String
        let icon: String // SF Symbol
        let phase: Int
        let points: Int
        let actionLink: String? // Deep link or view identifier
        let steps: [String] // Detailed instructions
    }
    
    let allMissions: [Mission] = [
        // Phase 1: The Basics
        Mission(
            id: "budget_beginner",
            title: "Budget Beginner",
            description: "Set up a monthly budget",
            icon: "chart.pie.fill",
            phase: 1,
            points: 100,
            actionLink: "add_budget",
            steps: [
                "Tap the '+' button in the 'Budgets' section on your Wallet or Home screen.",
                "Enter a budget limit (e.g., $500).",
                "Name your category (e.g., 'Groceries').",
                "Choose an icon and color to make it recognizable.",
                "Tap 'Save' to create your first budget!"
            ]
        ),
        Mission(
            id: "personalizer",
            title: "Personalizer",
            description: "Create a custom category",
            icon: "paintbrush.fill",
            phase: 1,
            points: 50,
            actionLink: "add_category",
            steps: [
                "This mission completes automatically when you create a new Budget.",
                "Budgets in this app also act as your transaction categories.",
                "Try creating a budget for 'Coffee' or 'Transport' to customize your tracking."
            ]
        ),
        Mission(
            id: "goal_getter",
            title: "Goal Getter",
            description: "Create a savings goal",
            icon: "target",
            phase: 1,
            points: 50,
            actionLink: "add_goal",
            steps: [
                "Tap the '+' button in the 'Saving Goals' section on your Wallet screen.",
                "Enter the amount you want to save.",
                "Give your goal a name (e.g., 'New Laptop').",
                "Set a target date for when you want to achieve this.",
                "Tap 'Save' to start tracking your progress!"
            ]
        ),
        
        // Phase 2: Building Habits
        Mission(
            id: "streak_starter",
            title: "Streak Starter",
            description: "Log a transaction for 3 days in a row",
            icon: "flame.fill",
            phase: 2,
            points: 150,
            actionLink: nil,
            steps: [
                "Open the app and log at least one transaction every day.",
                "Do this for 3 consecutive days.",
                "You'll see your streak flame light up in the top header!",
                "Consistency is key to financial awareness."
            ]
        ),
        Mission(
            id: "insight_master",
            title: "Insight Master",
            description: "Open the Monthly Report",
            icon: "doc.text.magnifyingglass",
            phase: 2,
            points: 50,
            actionLink: "calendar_view",
            steps: [
                "Go to your Wallet tab.",
                "Scroll down to the Calendar section.",
                "The calendar gives you a bird's-eye view of your daily spending habits.",
                "Just viewing this report completes the mission!"
            ]
        ),
        Mission(
            id: "subscription_tracker",
            title: "Subscription Tracker",
            description: "Add a recurring transaction",
            icon: "arrow.triangle.2.circlepath",
            phase: 2,
            points: 100,
            actionLink: "add_recurring",
            steps: [
                "Tap the '+' button in the 'Recurring' section on your Wallet screen.",
                "Enter the amount and name for a regular bill (e.g., 'Netflix').",
                "Select how often it repeats (e.g., Monthly).",
                "Tap 'Save'. The app will now automatically add this for you!"
            ]
        ),
        
        // Phase 3: Power Features
        Mission(
            id: "widget_watcher",
            title: "Widget Watcher",
            description: "Open app from a Widget",
            icon: "square.dashed.inset.filled",
            phase: 3,
            points: 200,
            actionLink: "setup_widget_guide",
            steps: [
                "Go to your iPhone Home Screen and long-press on an empty area.",
                "Tap the '+' button in the top left corner.",
                "Search for 'FinanceTracker' (or your app name).",
                "Add a widget to your home screen.",
                "Tap the widget to open the app and complete this mission!"
            ]
        ),
        Mission(
            id: "speedster",
            title: "Speedster",
            description: "Log via Back Tap or Shortcut",
            icon: "bolt.fill",
            phase: 3,
            points: 200,
            actionLink: "setup_backtap_guide",
            steps: [
                "This requires setting up an iOS Shortcut or Back Tap.",
                "Open the 'Shortcuts' app on your iPhone.",
                "Create a shortcut that uses the 'Log Transaction' action from this app.",
                "Run the shortcut or assign it to Back Tap in iOS Settings -> Accessibility -> Touch -> Back Tap.",
                "Log a transaction using this method to win!"
            ]
        ),
        
        // Phase 4: Social & Global
        Mission(
            id: "social_splitter",
            title: "Social Splitter",
            description: "Split a bill with a friend",
            icon: "person.2.fill",
            phase: 4,
            points: 150,
            actionLink: "add_transaction_split",
            steps: [
                "Log a new transaction.",
                "Tap 'Split with Friends' before saving.",
                "Select a friend or group to split the cost with.",
                "Save the transaction. Your friend will receive a notification!"
            ]
        ),
        Mission(
            id: "global_traveler",
            title: "Global Traveler",
            description: "Log a foreign currency transaction",
            icon: "airplane",
            phase: 4,
            points: 150,
            actionLink: "travel_mode_guide",
            steps: [
                "Enable 'Travel Mode' in your Profile settings.",
                "Select a foreign currency (e.g., JPY, EUR).",
                "Log a transaction while this mode is active.",
                "The app automatically handles the exchange rate for you!"
            ]
        )
    ]
    
    // MARK: - Init
    private init() {
        // Listen to AppState or User changes if needed
    }
    
    // MARK: - Logic
    
    func loadUserData(userId: String) {
        let docRef = db.collection("users").document(userId)
        
        docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            
            DispatchQueue.main.async {
                self.points = data["points"] as? Int ?? 0
                if let missions = data["completedMissionIds"] as? [String] {
                    self.completedMissionIds = Set(missions)
                }
                self.updateCurrentPhase()
            }
        }
    }
    
    func completeMission(id: String) {
        guard !completedMissionIds.contains(id),
              let mission = allMissions.first(where: { $0.id == id }) else { return }
        
        // Optimistic UI update
        DispatchQueue.main.async {
            self.completedMissionIds.insert(id)
            self.points += mission.points
            self.latestCompletedMission = mission
            self.showCelebration = true
            self.updateCurrentPhase()
            
            // Haptic Feedback
            HapticManager.shared.success()
        }
        
        // Persist to Firebase
        guard let userId = AppState.shared.currentUserId as String?, !userId.isEmpty else { return }
        
        let docRef = db.collection("users").document(userId)
        docRef.updateData([
            "points": FieldValue.increment(Int64(mission.points)),
            "completedMissionIds": FieldValue.arrayUnion([id])
        ]) { error in
            if let error = error {
                DebugLogger.log("Error updating mission: \(error)")
            }
        }
    }
    
    private func updateCurrentPhase() {
        // Simple logic: If all missions in Phase 1 are done, unlock Phase 2, etc.
        let phase1Missions = allMissions.filter { $0.phase == 1 }
        let phase2Missions = allMissions.filter { $0.phase == 2 }
        let phase3Missions = allMissions.filter { $0.phase == 3 }
        
        let phase1Complete = phase1Missions.allSatisfy { completedMissionIds.contains($0.id) }
        let phase2Complete = phase2Missions.allSatisfy { completedMissionIds.contains($0.id) }
        let phase3Complete = phase3Missions.allSatisfy { completedMissionIds.contains($0.id) }
        
        if phase3Complete {
            currentPhase = 4
        } else if phase2Complete {
            currentPhase = 3
        } else if phase1Complete {
            currentPhase = 2
        } else {
            currentPhase = 1
        }
    }
    
    func getMissions(forPhase phase: Int) -> [Mission] {
        return allMissions.filter { $0.phase == phase }
    }
    
    // MARK: - Progress Helpers
    
    func progressForPhase(_ phase: Int) -> Double {
        let phaseMissions = getMissions(forPhase: phase)
        guard !phaseMissions.isEmpty else { return 0 }
        
        let completedCount = phaseMissions.filter { completedMissionIds.contains($0.id) }.count
        return Double(completedCount) / Double(phaseMissions.count)
    }
    
    // MARK: - Rewards System
    
    @Published var availableRewards: [FirestoreModels.Reward] = [
        FirestoreModels.Reward(id: "coffee_break", title: "Free Espresso", cost: 300, icon: "cup.and.saucer.fill", partnerName: "Bean & Brew", description: "Enjoy a free single-origin espresso at any Bean & Brew location.", colorHex: "#A0522D"),
        FirestoreModels.Reward(id: "gym_pass", title: "1-Day Gym Pass", cost: 500, icon: "dumbbell.fill", partnerName: "FitLife Gyms", description: "Get access to any FitLife gym for a full day workout.", colorHex: "#FF3B30"),
        FirestoreModels.Reward(id: "movie_night", title: "50% Off Ticket", cost: 450, icon: "popcorn.fill", partnerName: "Star Cinema", description: "Half price on any standard movie ticket.", colorHex: "#5856D6"),
        FirestoreModels.Reward(id: "streaming_trial", title: "1 Month Free", cost: 1000, icon: "play.tv.fill", partnerName: "StreamPlus", description: "One month of premium streaming, ad-free.", colorHex: "#007AFF"),
        FirestoreModels.Reward(id: "groceries_voucher", title: "$10 Voucher", cost: 1200, icon: "carrot.fill", partnerName: "FreshMart", description: "$10 off your next grocery bill over $50.", colorHex: "#34C759")
    ]
    
    @Published var redemptions: [FirestoreModels.Redemption] = []
    
    func redeem(reward: FirestoreModels.Reward) {
        // 1. Check Balance
        guard points >= reward.cost else { return }
        
        // 2. Deduct Points (Optimistic)
        let originalPoints = points
        points -= reward.cost
        
        // 3. Create Redemption
        let redemption = FirestoreModels.Redemption(
            rewardId: reward.id,
            rewardTitle: reward.title,
            rewardIcon: reward.icon,
            cost: reward.cost,
            date: Date(),
            code: generateRedemptionCode()
        )
        
        redemptions.insert(redemption, at: 0)
        HapticManager.shared.success()
        
        // 4. Persist to Firebase securely using Transaction
        guard let userId = AppState.shared.currentUserId as String?, !userId.isEmpty else { return }
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
                    
                    // Deduct points safely
                    transaction.updateData(["points": currentPoints - reward.cost], forDocument: docRef)
                    
                    // Save redemption (Subcollection)
                    let redemptionRef = docRef.collection("redemptions").document(redemption.id)
                    do {
                        try transaction.setData(from: redemption, forDocument: redemptionRef)
                    } catch let encodeError as NSError {
                        errorPointer?.pointee = encodeError
                        return nil
                    }
                    return true
                }
            } catch {
                DebugLogger.log("Redemption transaction failed: \(error)")
                // Rollback optimistic updates on failure
                DispatchQueue.main.async {
                    self.points = originalPoints
                    if let index = self.redemptions.firstIndex(where: { $0.id == redemption.id }) {
                        self.redemptions.remove(at: index)
                    }
                }
            }
        }
    }
    
    private func generateRedemptionCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in letters.randomElement()! })
    }
}
