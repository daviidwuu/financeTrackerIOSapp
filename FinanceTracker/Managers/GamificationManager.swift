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
        let steps: [String] // Text-only instructions (legacy)
        let tutorialSteps: [TutorialStep] // Rich tutorial data
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
            ],
            tutorialSteps: [
                TutorialStep(icon: "plus.circle.fill", iconColor: .blue, title: "Find the Add Button", description: "Go to your Wallet or Home screen. Look for the '+' button in the 'Budgets' section and tap it.", animationType: .bounce),
                TutorialStep(icon: "dollarsign.circle.fill", iconColor: .green, title: "Set Your Limit", description: "Enter a monthly budget limit. Start with something realistic — for example, $500 for groceries or $200 for dining out.", animationType: .pulse),
                TutorialStep(icon: "textformat", iconColor: .orange, title: "Name Your Category", description: "Give your budget a clear name like 'Groceries', 'Transport', or 'Coffee'. This becomes your spending category.", animationType: .float),
                TutorialStep(icon: "paintpalette.fill", iconColor: .purple, title: "Choose Style", description: "Pick an icon and color that makes your budget instantly recognizable at a glance.", animationType: .rotate),
                TutorialStep(icon: "checkmark.circle.fill", iconColor: Color(hex: "#34C759"), title: "Save & Track", description: "Tap 'Save' and you're done! Your budget will now track spending automatically. +100 points earned!", animationType: .bounce)
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
            ],
            tutorialSteps: [
                TutorialStep(icon: "lightbulb.fill", iconColor: .yellow, title: "How It Works", description: "In this app, budgets double as your spending categories. Creating a budget automatically creates a custom category.", animationType: .pulse),
                TutorialStep(icon: "plus.circle.fill", iconColor: .blue, title: "Create a Budget", description: "Go to Wallet → tap '+' on Budgets. The budget name becomes your new category — try 'Coffee', 'Transport', or 'Subscriptions'.", animationType: .bounce),
                TutorialStep(icon: "star.fill", iconColor: .orange, title: "Auto-Complete", description: "This mission completes automatically when you create any budget. Easy 50 points!", animationType: .float)
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
            ],
            tutorialSteps: [
                TutorialStep(icon: "target", iconColor: .red, title: "Open Savings Goals", description: "Head to your Wallet screen and find the 'Saving Goals' section. Tap the '+' button to start.", animationType: .pulse),
                TutorialStep(icon: "dollarsign.circle.fill", iconColor: .green, title: "Set Your Target", description: "Enter how much you want to save — whether it's $100 for a night out or $2,000 for a holiday.", animationType: .bounce),
                TutorialStep(icon: "pencil.line", iconColor: .blue, title: "Name & Date", description: "Give your goal a motivating name like 'New Laptop' or 'Japan Trip'. Set a target date to keep yourself accountable.", animationType: .float),
                TutorialStep(icon: "checkmark.circle.fill", iconColor: Color(hex: "#34C759"), title: "Track Progress", description: "Tap 'Save' and watch your progress grow! The app shows a beautiful progress bar as you get closer to your goal.", animationType: .bounce)
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
            ],
            tutorialSteps: [
                TutorialStep(icon: "flame.fill", iconColor: .orange, title: "Build Your Streak", description: "The key to financial awareness is consistency. Log at least one transaction every day to build a streak.", animationType: .pulse),
                TutorialStep(icon: "calendar", iconColor: .blue, title: "3 Days Straight", description: "Open the app each day and record your spending — even a coffee counts. Do this for 3 consecutive days.", animationType: .bounce),
                TutorialStep(icon: "bell.badge.fill", iconColor: .purple, title: "Enable Reminders", description: "Turn on daily reminders in Settings → Notifications to help you remember. A quick nudge before bedtime works great.", animationType: .float),
                TutorialStep(icon: "trophy.fill", iconColor: .yellow, title: "Watch It Grow", description: "Your streak flame appears in the header! The longer your streak, the more impressive it becomes. 150 bonus points for starting!", animationType: .rotate)
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
            ],
            tutorialSteps: [
                TutorialStep(icon: "wallet.pass.fill", iconColor: .blue, title: "Go to Wallet", description: "Tap the Wallet tab at the bottom of your screen to see your financial overview.", animationType: .bounce),
                TutorialStep(icon: "calendar", iconColor: .red, title: "Find the Calendar", description: "Scroll down past your budgets to find the Calendar section. It shows a color-coded view of your daily spending.", animationType: .float),
                TutorialStep(icon: "eye.fill", iconColor: Color(hex: "#34C759"), title: "Just Look!", description: "Simply opening the calendar view completes this mission. Easy 50 points! But take a moment to see your spending patterns.", animationType: .pulse)
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
            ],
            tutorialSteps: [
                TutorialStep(icon: "plus.circle.fill", iconColor: .blue, title: "Add Recurring", description: "In your Wallet screen, find the 'Recurring' section and tap '+' to add a subscription or regular bill.", animationType: .bounce),
                TutorialStep(icon: "dollarsign.circle.fill", iconColor: .green, title: "Enter Details", description: "Type the amount and name — like 'Netflix $12.99' or 'Gym Membership $50'. These are bills you pay regularly.", animationType: .pulse),
                TutorialStep(icon: "clock.arrow.circlepath", iconColor: .orange, title: "Set Frequency", description: "Choose how often it repeats: Monthly, Weekly, or even Daily. Most subscriptions are monthly.", animationType: .rotate),
                TutorialStep(icon: "bell.badge.fill", iconColor: .purple, title: "Auto-Tracking", description: "Save it and the app will automatically log this transaction each period. Never forget a subscription payment again!", animationType: .float)
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
            ],
            tutorialSteps: [
                TutorialStep(icon: "hand.tap.fill", iconColor: .blue, title: "Long Press Home Screen", description: "Go to your iPhone Home Screen. Long press on any empty area until the apps start jiggling.", animationType: .bounce),
                TutorialStep(icon: "plus.circle.fill", iconColor: Color(hex: "#34C759"), title: "Tap the + Button", description: "Look for the '+' button in the top-left corner of your screen. Tap it to open the widget gallery.", animationType: .pulse),
                TutorialStep(icon: "magnifyingglass", iconColor: .orange, title: "Search for the App", description: "In the widget gallery, search for 'wym' to find the app's widgets. You'll see multiple size options.", animationType: .float),
                TutorialStep(icon: "square.grid.2x2.fill", iconColor: .purple, title: "Choose a Widget", description: "Pick the widget style you like — small for quick balance view, medium for spending breakdown, or large for the full dashboard.", animationType: .rotate),
                TutorialStep(icon: "hand.point.up.left.fill", iconColor: .red, title: "Tap to Complete!", description: "Once added, tap the widget from your Home Screen to open the app. Mission complete! +200 points!", animationType: .bounce)
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
            ],
            tutorialSteps: [
                TutorialStep(icon: "gear", iconColor: .gray, title: "Open Settings", description: "Go to your iPhone Settings app. We'll set up Back Tap so you can log expenses by tapping the back of your phone!", animationType: .rotate),
                TutorialStep(icon: "hand.raised.fill", iconColor: .blue, title: "Find Accessibility", description: "Navigate to Settings → Accessibility → Touch. Scroll down to find 'Back Tap'.", animationType: .bounce),
                TutorialStep(icon: "hand.tap.fill", iconColor: .purple, title: "Choose Tap Type", description: "Select 'Double Tap' or 'Triple Tap'. Double tap is more convenient, triple tap is less likely to trigger accidentally.", animationType: .pulse),
                TutorialStep(icon: "link", iconColor: Color(hex: "#34C759"), title: "Set the Shortcut", description: "Scroll down to the 'Shortcuts' section and select the app's 'Log Transaction' shortcut.", animationType: .float),
                TutorialStep(icon: "bolt.fill", iconColor: .yellow, title: "Tap & Log!", description: "Now just tap the back of your phone to instantly open the transaction logger. The fastest way to track expenses! +200 points!", animationType: .bounce)
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
            ],
            tutorialSteps: [
                TutorialStep(icon: "plus.circle.fill", iconColor: .blue, title: "Start a Transaction", description: "Tap '+' to log a new transaction as you normally would — enter the amount and details of the expense.", animationType: .bounce),
                TutorialStep(icon: "person.2.fill", iconColor: .purple, title: "Tap Split", description: "Before saving, look for the 'Split with Friends' option. Tap it to open the split configuration.", animationType: .pulse),
                TutorialStep(icon: "person.crop.circle.badge.checkmark", iconColor: Color(hex: "#34C759"), title: "Choose Friends", description: "Select a friend or group to split with. You can split equally, by exact amounts, or by percentages.", animationType: .float),
                TutorialStep(icon: "bell.badge.fill", iconColor: .orange, title: "Send & Track", description: "Save the transaction. Your friend gets a notification and you can track who has paid back in the Social tab. +150 points!", animationType: .rotate)
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
            ],
            tutorialSteps: [
                TutorialStep(icon: "person.circle.fill", iconColor: .blue, title: "Open Profile", description: "Go to your Profile tab and find the Settings section. Look for 'Travel Mode' or 'Currency Settings'.", animationType: .bounce),
                TutorialStep(icon: "globe.americas.fill", iconColor: .green, title: "Enable Travel Mode", description: "Turn on Travel Mode and select a foreign currency — like JPY for Japan, EUR for Europe, or THB for Thailand.", animationType: .rotate),
                TutorialStep(icon: "plus.circle.fill", iconColor: .orange, title: "Log in Foreign Currency", description: "Add a transaction normally. The app now shows the foreign currency. Enter the amount as you paid it abroad.", animationType: .pulse),
                TutorialStep(icon: "arrow.triangle.2.circlepath", iconColor: .purple, title: "Auto Exchange Rate", description: "The app automatically converts to your home currency using real exchange rates. Track travel spending effortlessly! +150 points!", animationType: .float)
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
    
    // MARK: - Redemptions (Local for display — actual redemption through Cloud Function)
    
    @Published var redemptions: [FirestoreModels.Redemption] = []
    
    private func generateRedemptionCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in letters.randomElement()! })
    }
}
