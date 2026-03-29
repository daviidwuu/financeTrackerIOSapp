import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var nav = AppNavigationState.shared
    // Repositories moved to AppState
    var transactionRepo: TransactionRepository { appState.transactionRepo }
    var budgetRepo: BudgetRepository { appState.budgetRepo }
    // RecurringRepo was unused in body, but removing state object ref
    var recurringRepo: RecurringTransactionRepository { appState.recurringRepo }
    @State private var showAddTransaction = false
    @State private var deepLinkCategory: String? // New state for deep link
    @Environment(\.colorScheme) var colorScheme
    // @State private var selectedTab = 0 // Moved to AppState
    @State private var showPostOnboardingGuide = false
    @State private var showWhatsNew = false

    /// Handles transaction saves: builds the Firestore model, persists, and fires
    /// all post-save side-effects (notifications, budget alerts, widget refresh).
    private var transactionCoordinator: TransactionCoordinator {
        TransactionCoordinator(
            transactionRepo: transactionRepo,
            budgetRepo: budgetRepo,
            currentUserIdProvider: { self.appState.currentUserId }
        )
    }

    private var whatsNewItems: [String] {
        [
            "Monetization is now production-ready: configurable ad unit IDs and paywall links.",
            "Improved subscription purchase flow with better cancellation handling.",
            "Better release UX with in-app What's New and dynamic version display."
        ]
    }

    var body: some View {
        TabView(selection: Binding(
            get: { nav.selectedTab },
            set: { newValue in
                if newValue == 3 {
                    HapticManager.shared.light()
                    showAddTransaction = true
                } else {
                    nav.selectedTab = newValue
                }
            }
        )) {
            TabSection {
                Tab("Home", systemImage: "square.grid.2x2.fill", value: 0) {
                    HomeView()
                }

                Tab("Social", systemImage: "person.2.fill", value: 1) {
                    SocialDashboardView()
                }

                Tab("Wallet", systemImage: "creditcard.fill", value: 2) {
                    WalletView()
                }
            }

            // Repurposed Search Tab as Action Button
            Tab("Add", systemImage: "plus", value: 3, role: .search) {
                // This view appears when the tab is selected, but thanks to the binding interceptor
                // above, we never actually switch to this tab. It just serves as a button.
                Color.clear
            }
        }
        .onChange(of: nav.selectedTab) { _, newValue in
            // Trigger haptic feedback on tab change
            if newValue != 3 {
                HapticManager.shared.selection()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.primary)
        .sheet(isPresented: $nav.showDailySummary) {
            AllTransactionsView(
                transactionRepo: transactionRepo,
                budgetRepo: budgetRepo,
                initialDate: nav.dailySummaryDate
            )
            .environmentObject(appState)
            .presentationBackground(Color.backgroundPrimary)
        }
        .sheet(isPresented: $showAddTransaction, onDismiss: {
            deepLinkCategory = nil // Reset on dismiss
        }) {
            AddTransactionView(initialCategoryName: deepLinkCategory, onSave: { transaction in
                transactionCoordinator.addTransaction(transaction)
            })
            .presentationBackground(Color.backgroundPrimary)
        }
        .onOpenURL { url in
            if url.scheme == "financetracker" && url.host == "add-transaction" {
                // Parse Query Params
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems {
                    if let category = queryItems.first(where: { $0.name == "category" })?.value {
                        // FIX #28: Validate category exists before setting it
                        if budgetRepo.budgets.contains(where: { $0.category == category }) {
                            deepLinkCategory = category
                        } else {
                            DebugLogger.log("Deep link category '\(category)' not found — opening without pre-selection")
                        }
                    }
                }
                showAddTransaction = true
            }
        }
        .sheet(isPresented: $showPostOnboardingGuide) {
            PostOnboardingGuideView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(
                version: AppConfig.versionDisplayString,
                items: whatsNewItems,
                onDismiss: {
                    WhatsNewManager.shared.markSeen()
                }
            )
            .presentationBackground(Color.backgroundPrimary)
        }
        .onAppear {
            // Check if user is new and hasn't seen the guide
            if appState.hasCompletedOnboarding && !appState.hasSeenPostOnboardingGuide {
                // Small delay to ensure view is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showPostOnboardingGuide = true
                }
            }
            // Request Ad Tracking Permission
            AdManager.shared.requestATT()

            if appState.hasCompletedOnboarding && WhatsNewManager.shared.shouldShow() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showWhatsNew = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchTab"))) { notification in
            if let tabName = notification.userInfo?["tab"] as? String {
                if tabName == "wallet" {
                    nav.selectedTab = 2 // Fixed index from 1 to 2 based on previous tag
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleDeepLink"))) { notification in
            if let link = notification.userInfo?["link"] as? String {
                handleDeepLink(link)
            }
        }
    }

    private func handleDeepLink(_ link: String) {
        // Dismiss any active sheets first (if possible, though MissionHub dismisses itself)
        showAddTransaction = false
        showPostOnboardingGuide = false

        switch link {
        case "add_budget", "add_category", "add_goal", "add_recurring", "calendar_view":
            // Switch to Wallet
            nav.selectedTab = 2
            // Post notification for WalletView to handle specific sheet
            NotificationCenter.default.post(
                name: NSNotification.Name("SwitchTab"),
                object: nil,
                userInfo: ["tab": "wallet", "action": link]
            )

        case "add_transaction", "add_transaction_split":
            // Stay on current tab (or switch to Home), open Add Transaction
            showAddTransaction = true

        case "travel_mode_guide":
            appState.showProfile = true

        case "setup_widget_guide", "setup_backtap_guide":
            // For now, just show alerts or maybe nothing as guides aren't implemented
            // Could open a specific guide sheet catch-all
            // HapticManager.shared.notification(.warning)
            break

        default:
            break
        }
    }
}

extension Date {
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        // FIX #21: Remove force unwrap to prevent crash
        return calendar.date(from: components) ?? self
    }
}

#Preview {
    ContentView()
}
