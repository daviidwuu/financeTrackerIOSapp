import SwiftUI
struct ContentView: View {
    @EnvironmentObject var appState: AppState
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
    @AppStorage("budgetAlertThreshold") private var budgetAlertThreshold: Double = 0.8
    
    var body: some View {
        TabView(selection: Binding(
            get: { appState.selectedTab },
            set: { newValue in
                if newValue == 3 {
                    HapticManager.shared.light()
                    showAddTransaction = true
                } else {
                    appState.selectedTab = newValue
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
        .onChange(of: appState.selectedTab) { _, newValue in
            // Trigger haptic feedback on tab change
            if newValue != 3 {
                HapticManager.shared.selection()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.primary)
        .sheet(isPresented: $appState.showDailySummary) {
            AllTransactionsView(
                transactionRepo: transactionRepo,
                budgetRepo: budgetRepo,
                initialDate: appState.dailySummaryDate
            )
            .environmentObject(appState)
            .presentationBackground(Color.backgroundPrimary)
        }
        .sheet(isPresented: $showAddTransaction, onDismiss: {
            deepLinkCategory = nil // Reset on dismiss
        }) {
            AddTransactionView(initialCategoryName: deepLinkCategory, onSave: { transaction in
                addTransaction(transaction)
            })
            .presentationBackground(Color.backgroundPrimary)
        }
        .onOpenURL { url in
            if url.scheme == "financetracker" && url.host == "add-transaction" {
                // Parse Query Params
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems {
                    if let category = queryItems.first(where: { $0.name == "category" })?.value {
                        deepLinkCategory = category
                    }
                }
                showAddTransaction = true
            }
        }
        .sheet(isPresented: $showPostOnboardingGuide) {
            PostOnboardingGuideView()
                .environmentObject(appState)
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
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchTab"))) { notification in
            if let tabName = notification.userInfo?["tab"] as? String {
                if tabName == "wallet" {
                    appState.selectedTab = 2 // Fixed index from 1 to 2 based on previous tag
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
            appState.selectedTab = 2
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
    
    private func addTransaction(_ transaction: TransactionFormData) {
        Task {
            do {
                // Convert UI Transaction to Firestore Transaction
                let amount = Double(transaction.amount) ?? 0.0
                
                // FIX #10: Validate amount is not zero
                guard amount != 0 else {
                    DebugLogger.log("Ignoring transaction with zero amount")
                    return
                }
                let firestoreTransaction = FirestoreModels.TransactionModel(
                    userId: appState.currentUserId, // Use global user ID
                    title: transaction.title,
                    subtitle: transaction.subtitle,
                    amount: amount,
                    date: transaction.date,
                    type: amount < 0 ? "expense" : "income",
                    createdAt: Date(),
                    icon: transaction.icon,
                    colorHex: transaction.color.toHex() ?? "#000000",
                    note: transaction.notes,
                    
                    // Travel / Currency Support
                    source: nil, // Add explicitly or skip if defaulted
                    // Location
                    latitude: transaction.latitude,
                    longitude: transaction.longitude,
                    locationName: transaction.locationName,
                    
                    splits: nil,
                     
                    originalAmount: transaction.originalAmount,
                    currencyCode: transaction.currencyCode,
                    exchangeRate: transaction.exchangeRate
                )
                try await transactionRepo.addTransaction(firestoreTransaction)
                
                // Send notification after successful save
                NotificationManager.shared.sendTransactionNotification(
                    amount: amount,
                    category: transaction.title,
                    type: transaction.type,
                    originalAmount: transaction.originalAmount,
                    currencyCode: transaction.currencyCode
                )
                
                // Check budget warnings
                checkBudgetStatus(for: transaction.title, amount: amount)
                
                // Update Quick Log Categories (Top 4 from Budgets)
                let topBudgets = budgetRepo.budgets
                    .filter { $0.category.lowercased() != "income" }
                    .prefix(4)
                    .map {
                        WidgetDataManager.WidgetCategory(
                            name: $0.category,
                            icon: $0.icon,
                            colorHex: $0.colorHex
                        )
                    }
                WidgetDataManager.shared.saveQuickLogCategories(Array(topBudgets))
                
            } catch {
                DebugLogger.log("Failed to add transaction: \(error)")
            }
        }
    }
    
    private func checkBudgetStatus(for category: String, amount: Double) {
        // Only check expenses
        guard amount < 0 else { return }
        
        // Find matching budget
        if let budget = budgetRepo.budgets.first(where: { $0.category == category }) {
            let spent = budget.spentAmount(transactions: transactionRepo.transactions)
            let totalLimit = budget.totalAmount
            
            // Validate totalLimit to avoid division by zero crash
            guard totalLimit > 0 else { return }
            
            // Calculate percentage used
            let percent = (spent / totalLimit) * 100
            guard !percent.isNaN && !percent.isInfinite else { return }
            
            let percentUsed = Int(percent)
            
            // Warn if over configured threshold
            let threshold = Int(budgetAlertThreshold * 100)
            if percentUsed >= threshold {
                let remaining = totalLimit - spent
                NotificationManager.shared.sendBudgetWarning(
                    category: category,
                    percentUsed: percentUsed,
                    remaining: remaining
                )
            }
        }
    }
}

extension Date {
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)!
    }
}

#Preview {
    ContentView()
}
