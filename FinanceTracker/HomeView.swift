import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    var monthlyIncome: Double {
        recurringRepo.recurringTransactions
            .filter { $0.type == "income" }
            .reduce(0) { sum, transaction in
                switch transaction.frequency {
                case "Weekly": return sum + (transaction.amount * 52.0 / 12.0)
                case "Bi-Weekly": return sum + (transaction.amount * 26.0 / 12.0)
                case "Yearly": return sum + (transaction.amount / 12.0)
                default: return sum + transaction.amount
                }
            }
    }
    
    @StateObject private var transactionRepo = TransactionRepository()
    @StateObject private var budgetRepo = BudgetRepository()
    @StateObject private var recurringRepo = RecurringTransactionRepository()
    
    @State private var showAddTransaction = false
    // showProfile moved to AppState
    @State private var showAllTransactions = false
    @State private var selectedTransaction: FirestoreModels.Transaction?
    @State private var transactionToEdit: FirestoreModels.Transaction?
    @State private var showRemainingBudget = false
    @State private var isAnimating = false
    
    var totalBudget: Double {
        // Exclude income budgets
        budgetRepo.budgets.filter { $0.type != "income" }.reduce(0) { sum, budget in
            // Normalize to monthly
            var monthlyAmount = budget.totalAmount
            switch budget.frequency {
            case "Weekly": monthlyAmount = budget.totalAmount * 52.0 / 12.0
            case "Bi-Weekly": monthlyAmount = budget.totalAmount * 26.0 / 12.0
            case "Yearly": monthlyAmount = budget.totalAmount / 12.0
            default: break
            }
            return sum + monthlyAmount
        }
    }
    
    var totalSpent: Double {
        let calendar = Calendar.current
        let currentMonthTransactions = transactionRepo.transactions.filter { transaction in
            // Only count expenses
            guard transaction.amount < 0 else { return false }
            // Filter by current month
            return calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
        return currentMonthTransactions.reduce(0) { $0 + abs($1.amount) }
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
                                    HStack(spacing: 8) {
                                        Text(appState.userName.isEmpty ? "User" : appState.userName)
                                            .font(AppTypography.titleDisplay)
                                            .foregroundColor(.primary)
                                        
                                        // Streak Counter
                                        HStack(spacing: 4) {
                                            Image(systemName: "flame.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.orange)
                                                .scaleEffect(isAnimating ? 1.2 : 1.0)
                                                .animation(
                                                    Animation.easeInOut(duration: 1.0)
                                                        .repeatForever(autoreverses: true),
                                                    value: isAnimating
                                                )
                                            
                                            Text("\(appState.streakCount)")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.orange.opacity(0.15))
                                        )
                                        .onAppear {
                                            isAnimating = true
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: { appState.showProfile = true }) {
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
                                        Text("$\(String(format: "%.2f", showRemainingBudget ? (totalBudget - totalSpent) : totalSpent))")
                                            .font(AppTypography.prominentBalance)
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
                                                .frame(width: min(geometry.size.width * (totalSpent / max(totalBudget, 0.01)), geometry.size.width))
                                        , alignment: .leading)
                                        .clipShape(Capsule())
                                }
                                .frame(height: 24)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                            .padding(24)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
                        }

                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.bottom, AppSpacing.compact)
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
                        if transactionRepo.transactions.isEmpty {
                            EmptyStateView(
                                icon: "tray.fill",
                                title: "No Transactions",
                                message: "Your recent spending will show up here.",
                                actionTitle: "Add One",
                                action: { showAddTransaction = true }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(transactionRepo.transactions.prefix(5)) { transaction in
                                TransactionRow(transaction: transaction)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .cornerRadius(AppRadius.medium)
                                    .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .padding(.bottom, AppSpacing.compact)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            HapticManager.shared.heavy()
                                            deleteTransaction(transaction)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            HapticManager.shared.medium()
                                            transactionToEdit = transaction
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .onTapGesture {
                                        HapticManager.shared.light()
                                        selectedTransaction = transaction
                                    }
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
                    TransactionDetailView(transaction: transaction) { original, updated in
                        updateTransaction(original, with: updated)
                    }
                    .environmentObject(appState)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
                .sheet(item: $transactionToEdit) { transaction in
                    AddTransactionView(transactionToEdit: transaction, onSave: { updatedTransaction in
                        updateTransaction(transaction, with: updatedTransaction)
                    })
                }
                .sheet(isPresented: $appState.showProfile) {
                    ProfileView()
                        .presentationBackground(Color.backgroundPrimary)
                }
                .sheet(isPresented: $showAllTransactions) {
                    AllTransactionsView(
                        transactionRepo: transactionRepo,
                        budgetRepo: budgetRepo
                    )
                    .environmentObject(appState)
                    .presentationBackground(Color.backgroundPrimary)
                }

                .sheet(isPresented: $showAddTransaction) {
                    AddTransactionView(onSave: { transaction in
                        addTransaction(transaction)
                    })
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Start listening to transactions when view appears
                if !appState.currentUserId.isEmpty {
                    transactionRepo.startListening(userId: appState.currentUserId)
                    budgetRepo.startListening(userId: appState.currentUserId)
                    recurringRepo.startListening(userId: appState.currentUserId)
                }
            }
            .onDisappear {
                transactionRepo.stopListening()
                budgetRepo.stopListening()
                recurringRepo.stopListening()
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
                    currencyCode: transaction.currencyCode,
                    exchangeRate: transaction.exchangeRate,
                    originalAmount: transaction.originalAmount
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
            } catch {
                DebugLogger.log("Failed to add transaction: \(error)")
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
                DebugLogger.log("Failed to update transaction: \(error)")
            }
        }
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.Transaction) {
        guard let id = transaction.id else { return }
        Task {
            do {
                try await transactionRepo.deleteTransaction(id: id)
            } catch {
                DebugLogger.log("Failed to delete transaction: \(error)")
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
    
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: date)
        
        if calendar.isDateInToday(date) {
            return "Today at \(timeString)"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday at \(timeString)"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
            return "\(dateFormatter.string(from: date)) at \(timeString)"
        }
    }
    
    private func getSubtitleText() -> String? {
        let noteText = (transaction.note?.isEmpty == false) ? transaction.note : nil
        
        var amountText: String? = nil
        if let originalAmount = transaction.originalAmount,
           let currency = transaction.currencyCode {
            let amountString = String(format: "%.2f", abs(originalAmount))
            amountText = "(\(currency)$\(amountString))"
        }
        
        if let n = noteText, let a = amountText {
            return "\(n) \(a)"
        } else if let n = noteText {
            return n
        } else if let a = amountText {
            return a
        }
        return nil
    }

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            Circle()
                .fill(Color(hex: categoryColor).opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: categoryIcon)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: categoryColor))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // For Income, always show Category Name (subtitle) or "Income" as title
                Text(transaction.type == "income" ? (transaction.subtitle ?? "Income") : transaction.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Subtitle logic
                if transaction.type != "income" {
                    if let subtitle = transaction.subtitle, !subtitle.isEmpty, subtitle != transaction.title {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Show note (or original title if it was hijackng description in legacy income)
                // Travel Mode: Show (Note) Currency$Amount
                if let subtitleText = getSubtitleText() {
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if transaction.type == "income" && transaction.title != (transaction.subtitle ?? "Income") {
                     // Fallback for legacy data where title was description
                    Text(transaction.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(formattedDate(transaction.date))
                    .font(.caption2)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
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
                budgetRepo.startListening(userId: appState.currentUserId)
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
