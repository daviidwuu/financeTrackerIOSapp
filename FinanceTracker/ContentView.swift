import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var transactionRepo = TransactionRepository()
    @State private var showAddTransaction = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem {
                        Image(systemName: "square.grid.2x2.fill")
                        Text("Dashboard")
                    }
                
                WalletView()
                    .tabItem {
                        Image(systemName: "creditcard.fill")
                        Text("Wallet")
                    }
            }
            .preferredColorScheme(.none) // Respect system setting
            
            // Floating Action Button
            Button(action: {
                HapticManager.shared.medium()
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
            .padding(.bottom, 6) // Fine tune position to sit nicely in the tab bar center
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(onSave: { transaction in
                    addTransaction(transaction)
                })
                .presentationDetents([.fraction(0.65)])
                .presentationDragIndicator(.visible)
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
                    createdAt: Date()
                )
                try await transactionRepo.addTransaction(firestoreTransaction)
                
                // Send notification after successful save
                NotificationManager.shared.sendTransactionNotification(
                    amount: amount,
                    category: transaction.title,
                    type: transaction.type
                )
            } catch {
                print("Failed to add transaction: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
