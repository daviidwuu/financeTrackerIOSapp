import SwiftUI

struct WalletView: View {
    @EnvironmentObject var appState: AppState
    
    @StateObject private var savingGoalRepo = SavingGoalRepository()
    @StateObject private var recurringRepo = RecurringTransactionRepository()
    @StateObject private var budgetRepo = BudgetRepository()
    @StateObject private var transactionRepo = TransactionRepository()
    
    @State private var showAddSavingGoal = false
    @State private var showAddRecurring = false
    @State private var showAddBudget = false
    
    @State private var goalToEdit: FirestoreModels.SavingGoal?
    @State private var recurringToEdit: FirestoreModels.RecurringTransaction?
    @State private var budgetToEdit: FirestoreModels.CategoryBudget?
    @State private var showEditBalance = false
    @State private var balanceInput = ""
    
    @AppStorage("initialBalance") private var initialBalance = 0.0
    @AppStorage("monthlyIncome") private var monthlyIncome = 5000.0 // Changed from monthlyBudget
    @State private var showDetails = false
    
    var totalBalance: Double {
        // Initial balance + all-time net (income - expenses)
        let allTimeNet = transactionRepo.transactions.reduce(0) { $0 + $1.amount }
        return initialBalance + allTimeNet
    }
    
    var totalBudget: Double {
        budgetRepo.budgets.reduce(0) { $0 + $1.totalAmount }
    }
    
    var incomeLeft: Double {
        let calendar = Calendar.current
        let currentMonthTransactions = transactionRepo.transactions.filter { transaction in
            guard transaction.type == "expense" else { return false }
            return calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
        let totalSpent = currentMonthTransactions.reduce(0) { $0 + $1.amount } // amount is negative
        return monthlyIncome + totalSpent // 5000 + (-200) = 4800
    }
    
    var currentMonthIncome: Double {
        let calendar = Calendar.current
        let currentMonthTransactions = transactionRepo.transactions.filter { transaction in
            guard transaction.type == "income" else { return false }
            return calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
        return currentMonthTransactions.reduce(0) { $0 + $1.amount }
    }
    
    var totalExpense: Double {
        // All-time total expenses (negative amounts)
        let allExpenses = transactionRepo.transactions.filter { $0.type == "expense" }
        return abs(allExpenses.reduce(0) { $0 + $1.amount })
    }
    
    var netCashFlow: Double {
        let calendar = Calendar.current
        let currentMonthTransactions = transactionRepo.transactions.filter { transaction in
            return calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
        return currentMonthTransactions.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                List {
                    // Header Section
                    Section {
                        HStack {
                            Text("Wallet")
                                .font(AppTypography.titleDisplay)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.top, 10)
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    // Section 1: Financial Overview (Balance Card)
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            // Total Balance
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Total Balance")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                
                                Text("$\(String(format: "%.2f", totalBalance))")
                                    .font(AppTypography.sectionHeader)
                                    .foregroundColor(totalBalance >= 0 ? .primary : .red)
                            }
                        }
                        .padding(.vertical, AppSpacing.compact)
                        .padding(AppSpacing.margin)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipped()
                        .cornerRadius(AppRadius.medium)
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.section, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle()) // Make entire area tappable
                        .onTapGesture {
                            HapticManager.shared.light()
                            showEditBalance.toggle()
                        }
                    }
                    
                    // Section 2: Saving Goals
                    Section(header:
                        HStack {
                            Text("Saving Goals").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                            Spacer()
                            Button(action: { 
                                goalToEdit = nil
                                showAddSavingGoal = true 
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                    ) {
                        if savingGoalRepo.savingGoals.isEmpty {
                            EmptyStateView(
                                icon: "target",
                                title: "No Goals",
                                message: "Set a saving goal to start tracking your progress!",
                                actionTitle: "Add Goal",
                                action: { showAddSavingGoal = true }
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.element, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(savingGoalRepo.savingGoals) { goal in
                                HStack {
                                    Image(systemName: goal.icon)
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(Color(hex: goal.colorHex))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading) {
                                        Text(goal.name)
                                            .font(.headline)
                                        Text("$\(Int(goal.currentAmount)) / $\(Int(goal.targetAmount))")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(Int((goal.currentAmount / goal.targetAmount) * 100))%")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.medium)
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.element, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteSavingGoal(goal)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        goalToEdit = goal
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear) // Ensure Section background is clear
                    
                    // Section 3: Calendar
                    Section {
                        VStack(spacing: 8) {
                            CalendarView(transactions: transactionRepo.transactions)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: AppSpacing.section, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    
                    // Section 4: Recurring Transactions
                    Section(header:
                        HStack {
                            Text("Recurring").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                            Spacer()
                            Button(action: { 
                                recurringToEdit = nil
                                showAddRecurring = true 
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                    ) {
                        if recurringRepo.recurringTransactions.isEmpty {
                            EmptyStateView(
                                icon: "arrow.2.squarepath",
                                title: "No Recurring",
                                message: "Add subscriptions or bills to track your future spending.",
                                actionTitle: "Add Recurring",
                                action: { showAddRecurring = true }
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.element, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(recurringRepo.recurringTransactions) { recurring in
                                HStack(spacing: AppSpacing.element) {
                                    // Icon
                                    Image(systemName: recurring.icon)
                                        .font(.title2)
                                        .frame(width: 50, height: 50)
                                        .background(Color(hex: recurring.colorHex).opacity(0.2))
                                        .foregroundColor(Color(hex: recurring.colorHex))
                                        .clipShape(Circle())
                                    
                                    // Content
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(recurring.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        if let note = recurring.note, !note.isEmpty {
                                            Text(note)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("$\(Int(recurring.amount))")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(recurring.frequency)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(hex: recurring.colorHex).opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.medium)
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.element, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteRecurringTransaction(recurring)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        recurringToEdit = recurring
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)

                    // Section 5: Budgets
                    Section(header:
                        HStack {
                            Text("Budgets").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                            Spacer()
                            Button(action: { 
                                budgetToEdit = nil
                                showAddBudget = true 
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                    ) {
                        if budgetRepo.budgets.isEmpty {
                            EmptyStateView(
                                icon: "chart.pie.fill",
                                title: "No Budgets",
                                message: "Organize your spending with category budgets.",
                                actionTitle: "Add Budget",
                                action: { showAddBudget = true }
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.element, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(budgetRepo.budgets) { budget in
                                HStack(spacing: AppSpacing.element) {
                                    Image(systemName: budget.icon)
                                        .frame(width: 40, height: 40)
                                        .background(Color(hex: budget.colorHex).opacity(0.2))
                                        .foregroundColor(Color(hex: budget.colorHex))
                                        .clipShape(Circle())
                                    Text(budget.category)
                                        .font(.headline)
                                    Spacer()
                                    Text("$\(Int(budget.remainingAmount(transactions: transactionRepo.transactions))) left")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.medium)
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.element, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteBudget(budget)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        budgetToEdit = budget
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .onAppear {
                    if !appState.currentUserId.isEmpty {
                        savingGoalRepo.startListening(userId: appState.currentUserId)
                        recurringRepo.startListening(userId: appState.currentUserId)
                        transactionRepo.startListening(userId: appState.currentUserId)
                        
                        let calendar = Calendar.current
                        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
                        budgetRepo.startListening(userId: appState.currentUserId, monthStartDate: startOfMonth)
                    }
                    checkForNewMonth()
                }
                .onDisappear {
                    savingGoalRepo.stopListening()
                    recurringRepo.stopListening()
                    budgetRepo.stopListening()
                    transactionRepo.stopListening()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddSavingGoal) {
                AddSavingGoalView(onSave: { goal in
                    addSavingGoal(goal)
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $goalToEdit) { goal in
                AddSavingGoalView(goalToEdit: goal, onSave: { updatedGoal in
                    updateSavingGoal(goal, with: updatedGoal)
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddRecurring) {
                AddRecurringTransactionView(onSave: { transaction in
                    addRecurringTransaction(transaction)
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $recurringToEdit) { transaction in
                AddRecurringTransactionView(recurringToEdit: transaction, onSave: { updatedTransaction in
                    updateRecurringTransaction(transaction, with: updatedTransaction)
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddBudget) {
                AddBudgetView(onSave: { budget in
                    addBudget(budget)
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $budgetToEdit) { budget in
                AddBudgetView(budgetToEdit: budget, onSave: { updatedBudget in
                    updateBudget(budget, with: updatedBudget)
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showEditBalance) {
                WalletDetailsView(
                    initialBalance: $initialBalance,
                    income: currentMonthIncome,
                    expense: totalExpense,
                    netFlow: netCashFlow
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func deleteSavingGoal(_ goal: FirestoreModels.SavingGoal) {
        guard let id = goal.id else { return }
        Task {
            try? await savingGoalRepo.deleteSavingGoal(id: id)
        }
    }
    
    private func deleteRecurringTransaction(_ transaction: FirestoreModels.RecurringTransaction) {
        guard let id = transaction.id else { return }
        Task {
            try? await recurringRepo.deleteRecurringTransaction(id: id)
        }
    }
    
    private func deleteBudget(_ budget: FirestoreModels.CategoryBudget) {
        guard let id = budget.id else { return }
        Task {
            try? await budgetRepo.deleteBudget(id: id)
        }
    }
    
    private func addSavingGoal(_ goal: SavingGoal) {
        Task {
            let firestoreGoal = FirestoreModels.SavingGoal(
                name: goal.name,
                targetAmount: goal.targetAmount,
                currentAmount: goal.currentAmount,
                targetDate: goal.targetDate,
                icon: goal.icon,
                colorHex: goal.color.toHex() ?? "#000000",
                userId: appState.currentUserId,
                createdAt: Date()
            )
            try? await savingGoalRepo.addSavingGoal(firestoreGoal)
        }
    }
    
    private func updateSavingGoal(_ entity: FirestoreModels.SavingGoal, with goal: SavingGoal) {
        var updatedGoal = entity
        updatedGoal.name = goal.name
        updatedGoal.targetAmount = goal.targetAmount
        updatedGoal.currentAmount = goal.currentAmount
        updatedGoal.targetDate = goal.targetDate
        updatedGoal.icon = goal.icon
        updatedGoal.colorHex = goal.color.toHex() ?? "#000000"
        
        Task {
            try? await savingGoalRepo.updateSavingGoal(updatedGoal)
        }
    }
    
    private func addRecurringTransaction(_ transaction: RecurringTransaction) {
        Task {
            let firestoreTransaction = FirestoreModels.RecurringTransaction(
                name: transaction.name,
                amount: transaction.amount,
                frequency: transaction.frequency,
                startDate: Date(), // Default to now, or add to UI model
                icon: transaction.icon,
                colorHex: transaction.color.toHex() ?? "#000000",
                note: transaction.notes,
                userId: appState.currentUserId,
                createdAt: Date()
            )
            try? await recurringRepo.addRecurringTransaction(firestoreTransaction)
        }
    }
    
    private func updateRecurringTransaction(_ entity: FirestoreModels.RecurringTransaction, with transaction: RecurringTransaction) {
        var updatedTransaction = entity
        updatedTransaction.name = transaction.name
        updatedTransaction.amount = transaction.amount
        updatedTransaction.frequency = transaction.frequency
        updatedTransaction.icon = transaction.icon
        updatedTransaction.colorHex = transaction.color.toHex() ?? "#000000"
        updatedTransaction.note = transaction.notes
        
        Task {
            try? await recurringRepo.updateRecurringTransaction(updatedTransaction)
        }
    }
    
    private func addBudget(_ budget: Budget) {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        
        Task {
            let firestoreBudget = FirestoreModels.CategoryBudget(
                category: budget.category,
                totalAmount: budget.totalAmount,
                icon: budget.icon,
                colorHex: budget.color.toHex() ?? "#000000",
                frequency: budget.frequency,
                type: budget.type, // Pass type
                userId: appState.currentUserId,
                monthStartDate: startOfMonth,
                createdAt: Date()
            )
            try? await budgetRepo.addBudget(firestoreBudget)
        }
    }
    
    private func updateBudget(_ entity: FirestoreModels.CategoryBudget, with budget: Budget) {
        var updatedBudget = entity
        updatedBudget.category = budget.category
        updatedBudget.totalAmount = budget.totalAmount
        updatedBudget.icon = budget.icon
        updatedBudget.colorHex = budget.color.toHex() ?? "#000000"
        updatedBudget.frequency = budget.frequency
        updatedBudget.type = budget.type // Pass type
        
        Task {
            try? await budgetRepo.updateBudget(updatedBudget)
        }
    }
    
    private func checkForNewMonth() {
        // TODO: Implement Firestore-based month rollover logic
    }
}

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.gray.opacity(0.2),
                    lineWidth: 6
                )
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progress >= 0 ? Color.white : Color.red,
                    style: StrokeStyle(
                        lineWidth: 6,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
        }
    }
}

#Preview {
    WalletView()
        .environmentObject(AppState.shared)
}
