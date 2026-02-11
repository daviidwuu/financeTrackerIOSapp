import SwiftUI
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var transactionRepo = TransactionRepository()
    @StateObject private var budgetRepo = BudgetRepository()
    @StateObject private var recurringRepo = RecurringTransactionRepository()
    @State private var showAddTransaction = false
    @Environment(\.colorScheme) var colorScheme
    // @State private var selectedTab = 0 // Moved to AppState
    @State private var showPostOnboardingGuide = false
    @AppStorage("budgetAlertThreshold") private var budgetAlertThreshold: Double = 0.8
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tag(0)
                    .tabItem {
                        Image(systemName: "square.grid.2x2.fill")
                        Text("Home")
                    }
                
                SocialDashboardView()
                    .tag(1)
                    .tabItem {
                        Image(systemName: "person.2.fill")
                        Text("Social")
                    }
                
                WalletView()
                    .tag(2)
                    .tabItem {
                        Image(systemName: "creditcard.fill")
                        Text("Wallet")
                    }
            }
            
            // .preferredColorScheme(.none) removed to respect app-level setting
            
            // Floating Action Button
            if appState.selectedTab == 0 {
                Button(action: {
                    HapticManager.shared.medium()
                    // Refresh budgets when opening add
                    if !appState.currentUserId.isEmpty {
                        budgetRepo.startListening(userId: appState.currentUserId)
                    }
                    showAddTransaction = true
                }) {
                    Circle()
                    .fill(Color.primary)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .overlay(
                        Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                    )
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(isPresented: $appState.showDailySummary) {
            AllTransactionsView(
                transactionRepo: transactionRepo,
                budgetRepo: budgetRepo,
                initialDate: appState.dailySummaryDate
            )
            .environmentObject(appState)
            .presentationBackground(Color.backgroundPrimary)
        }
        .sheet(isPresented: $showAddTransaction) {
            AddTransactionView(onSave: { transaction in
                addTransaction(transaction)
            })
            .presentationBackground(Color.backgroundPrimary)
        }
        .onOpenURL { url in
            if url.scheme == "financetracker" && url.host == "add-transaction" {
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
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchTab"))) { notification in
            if let tabName = notification.userInfo?["tab"] as? String {
                if tabName == "wallet" {
                    appState.selectedTab = 1
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
    }
    
    private func addTransaction(_ transaction: Transaction) {
        Task {
            do {
                // Convert UI Transaction to Firestore Transaction
                let amount = Double(transaction.amount) ?? 0.0
                let firestoreTransaction = FirestoreModels.Transaction(
                    title: transaction.title,
                    subtitle: transaction.subtitle,
                    amount: amount,
                    date: transaction.date,
                    icon: transaction.icon,
                    colorHex: transaction.color.toHex() ?? "#000000",
                    note: transaction.notes,
                    type: amount < 0 ? "expense" : "income",
                    userId: appState.currentUserId, // Use global user ID
                    createdAt: Date(),
                    
                    // Travel / Currency Support
                    currencyCode: transaction.currencyCode,
                    exchangeRate: transaction.exchangeRate,
                    originalAmount: transaction.originalAmount,
                    
                    // Location
                    latitude: transaction.latitude,
                    longitude: transaction.longitude,
                    locationName: transaction.locationName
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
            let spent = budgetRepo.calculateSpent(for: category, transactions: transactionRepo.transactions)
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
