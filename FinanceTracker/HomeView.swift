import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    @AppStorage("monthlyIncome") private var monthlyIncome = 5000.0 // Changed from monthlyBudget
    
    @StateObject private var transactionRepo = TransactionRepository()
    @StateObject private var budgetRepo = BudgetRepository()
    
    @State private var showAddTransaction = false
    @State private var showProfile = false
    @State private var showAllTransactions = false
    @State private var selectedTransaction: FirestoreModels.Transaction?
    @State private var showRemainingBudget = false
    
    var totalSpent: Double {
        transactionRepo.transactions.reduce(0) { $0 + ($1.amount < 0 ? abs($1.amount) : 0) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    // Section 1: Header & Balance
                    Section {
                        VStack(spacing: 24) {
                            // Custom Header
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Welcome")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Text(appState.userName.isEmpty ? "User" : appState.userName)
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                                
                                Button(action: { showProfile = true }) {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.primary)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 10)
                            
                            // Balance Card
                            VStack(alignment: .leading, spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Balance")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("$\(String(format: "%.2f", showRemainingBudget ? (monthlyIncome - totalSpent) : totalSpent))")
                                            .font(.system(size: 42, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .contentTransition(.numericText())
                                        
                                        Text(showRemainingBudget ? "left" : "spent")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .transition(.opacity)
                                    }
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            showRemainingBudget.toggle()
                                        }
                                    }
                                }
                                
                                // Custom Pill-Shaped Progress Bar
                                GeometryReader { geometry in
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(height: 24)
                                        .overlay(
                                            Capsule()
                                                .fill(Color.white)
                                                .frame(width: min(geometry.size.width * (totalSpent / max(monthlyIncome, 1.0)), geometry.size.width))
                                        , alignment: .leading)
                                        .clipShape(Capsule())
                                }
                                .frame(height: 24)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                            .padding(24)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                        }

                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.bottom, 20)
                    }
                    
                    // Section 2: Recent Transactions
                    Section(header: 
                        HStack {
                            Text("Recent Transactions")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                HapticManager.shared.light()
                                showAllTransactions = true
                            }) {
                                Text("View All")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        .textCase(nil)
                    ) {
                        ForEach(transactionRepo.transactions.prefix(5)) { transaction in
                            TransactionRow(transaction: transaction)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(16)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.bottom, 8)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteTransaction(transaction)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        selectedTransaction = transaction
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                // FAB removed, shifted to ContentView
                
                .sheet(item: $selectedTransaction) { transaction in
                    AddTransactionView(transactionToEdit: transaction, onSave: { updatedTransaction in
                        updateTransaction(transaction, with: updatedTransaction)
                    })
                    .presentationDetents([.fraction(0.65)])
                    .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showProfile) {
                    ProfileView()
                }
                .sheet(isPresented: $showAllTransactions) {
                    AllTransactionsView(
                        transactionRepo: transactionRepo,
                        budgetRepo: budgetRepo
                    )
                    .environmentObject(appState)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Start listening to transactions when view appears
                if !appState.currentUserId.isEmpty {
                    transactionRepo.startListening(userId: appState.currentUserId)
                    let calendar = Calendar.current
                    let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
                    budgetRepo.startListening(userId: appState.currentUserId, monthStartDate: startOfMonth)
                }
            }
            .onDisappear {
                transactionRepo.stopListening()
                budgetRepo.stopListening()
            }
        }
    }
    
    private func updateTransaction(_ entity: FirestoreModels.Transaction, with transaction: Transaction) {
        Task {
            do {
                let amount = Double(transaction.amount) ?? 0.0
                var updatedTransaction = entity
                updatedTransaction.title = transaction.title
                updatedTransaction.subtitle = transaction.subtitle
                updatedTransaction.amount = amount
                updatedTransaction.date = transaction.date
                updatedTransaction.icon = transaction.icon
                updatedTransaction.colorHex = transaction.color.toHex() ?? "#000000"
                updatedTransaction.note = transaction.notes
                updatedTransaction.type = amount < 0 ? "expense" : "income"
                
                try await transactionRepo.updateTransaction(updatedTransaction)
            } catch {
                print("Failed to update transaction: \(error)")
            }
        }
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.Transaction) {
        guard let id = transaction.id else { return }
        Task {
            do {
                try await transactionRepo.deleteTransaction(id: id)
            } catch {
                print("Failed to delete transaction: \(error)")
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: FirestoreModels.Transaction
    @StateObject private var budgetRepo = BudgetRepository()
    @EnvironmentObject var appState: AppState
    
    // Dynamic lookup of category icon/color
    private var categoryIcon: String {
        if let budget = budgetRepo.budgets.first(where: { $0.category.lowercased() == (transaction.subtitle?.lowercased() ?? "") }) {
            return budget.icon
        }
        return "questionmark.circle.fill" // Fallback for "Others"
    }
    
    private var categoryColor: String {
        if let budget = budgetRepo.budgets.first(where: { $0.category.lowercased() == (transaction.subtitle?.lowercased() ?? "") }) {
            return budget.colorHex
        }
        return "#808080" // Gray for "Others"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color(hex: categoryColor).opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: categoryIcon)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: categoryColor))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                if let subtitle = transaction.subtitle, !subtitle.isEmpty, subtitle != transaction.title {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(String(format: "%@$%.2f", transaction.amount > 0 ? "+" : "", abs(transaction.amount)))
                .font(.system(.callout, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(transaction.amount > 0 ? .green : .primary)
        }
        .padding(16)
        .onAppear {
            if !appState.currentUserId.isEmpty {
                let calendar = Calendar.current
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
                budgetRepo.startListening(userId: appState.currentUserId, monthStartDate: startOfMonth)
            }
        }
        .onDisappear {
            budgetRepo.stopListening()
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState.shared)
}
