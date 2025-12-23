import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var transactionRepo = TransactionRepository()
    @StateObject private var budgetRepo = BudgetRepository()
    @State private var showAddTransaction = false
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                    .tabItem {
                        Image(systemName: "square.grid.2x2.fill")
                        Text("Dashboard")
                    }
                
                WalletView()
                    .tag(1)
                    .tabItem {
                        Image(systemName: "creditcard.fill")
                        Text("Wallet")
                    }
            }
            .preferredColorScheme(.none) // Respect system setting
            
            // Floating Action Button
            if selectedTab == 0 {
                Button(action: {
                    HapticManager.shared.medium()
                    // Refresh budgets when opening add
                    if !appState.currentUserId.isEmpty {
                        budgetRepo.startListening(userId: appState.currentUserId, monthStartDate: Date().startOfMonth())
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
        .sheet(isPresented: $showAddTransaction) {
            AddTransactionView(onSave: { transaction in
                addTransaction(transaction)
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.backgroundPrimary)
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
                    createdAt: Date()
                )
                try await transactionRepo.addTransaction(firestoreTransaction)
                
                // Send notification after successful save
                NotificationManager.shared.sendTransactionNotification(
                    amount: amount,
                    category: transaction.title,
                    type: transaction.type
                )
                
                // Check budget warnings
                checkBudgetStatus(for: transaction.title, amount: amount)
            } catch {
                print("Failed to add transaction: \(error)")
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
            
            // Calculate percentage used
            let percentUsed = Int((spent / totalLimit) * 100)
            
            // Warn if over 80%
            if percentUsed >= 80 {
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
