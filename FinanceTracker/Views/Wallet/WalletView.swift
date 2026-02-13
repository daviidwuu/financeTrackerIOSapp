import SwiftUI

struct WalletView: View {
    @EnvironmentObject var appState: AppState
    
    // Repositories moved to AppState
    var savingGoalRepo: SavingGoalRepository { appState.savingGoalRepo }
    var recurringRepo: RecurringTransactionRepository { appState.recurringRepo }
    var budgetRepo: BudgetRepository { appState.budgetRepo }
    var transactionRepo: TransactionRepository { appState.transactionRepo }
    
    @State private var showAddSavingGoal = false
    @State private var showAddRecurring = false
    @State private var showAddBudget = false
    @State private var errorState = ErrorState()
    @State private var undoState = UndoState()
    @State private var hiddenItemIds: Set<String> = []
    
    @State private var goalToEdit: FirestoreModels.SavingGoal?
    @State private var recurringToEdit: FirestoreModels.RecurringTransaction?
    @State private var budgetToEdit: FirestoreModels.CategoryBudget?
    @State private var showEditBalance = false
    @State private var balanceInput = ""
    
    @AppStorage("initialBalance") private var initialBalance = 0.0
    
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
    
    @State private var showDetails = false
    
    var totalBalance: Double {
        // Initial balance + all-time net (income - expenses)
        let allTimeNet = transactionRepo.transactions.reduce(0) { $0 + $1.amount }
        return initialBalance + allTimeNet
    }
    
    var totalBudget: Double {
        // Exclude income budgets and normalize to monthly
        budgetRepo.budgets.filter { $0.type != "income" }.reduce(0) { sum, budget in
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
    
    var incomeLeft: Double {
        let calendar = Calendar.current
        let currentMonthTransactions = transactionRepo.transactions.filter { transaction in
            guard transaction.type == "expense" else { return false }
            return calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
        let totalSpent = currentMonthTransactions.reduce(0) { $0 + $1.amount } // amount is negative
        return monthlyIncome + totalSpent
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
        NavigationStack {
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
                        .padding(.bottom, AppSpacing.compact) // Added spacing between header and card
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

                        .padding(AppSpacing.margin) // Changed from 24 to 20 (standard margin)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large)) // Consistent radius
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
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
                                HapticManager.shared.light()
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
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } else {
                            let pool = calculateAllTimeSavingsPool()
                            let sortedGoals = savingGoalRepo.savingGoals
                            
                            ForEach(sortedGoals) { goal in
                                let index = sortedGoals.firstIndex(where: { $0.id == goal.id }) ?? 0
                                let currentAmount = calculateGoalAllocation(for: index, in: sortedGoals, pool: pool)
                                
                                HStack {
                                    Image(systemName: goal.icon)
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 48, height: 48)
                                        .background(Color(hex: goal.colorHex))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal.name)
                                            .font(.headline)
                                        Text("$\(Int(currentAmount)) / $\(Int(goal.targetAmount))")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.secondary)
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "calendar")
                                                .font(.caption2)
                                            Text("Target: \(goal.targetDate.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(Int((currentAmount / goal.targetAmount) * 100))%")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: AppRadius.medium))
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        HapticManager.shared.heavy()
                                        deleteSavingGoal(goal)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        HapticManager.shared.medium()
                                        goalToEdit = goal
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                            .onMove(perform: moveSavingGoals)
                        }
                    }
                    .listRowBackground(Color.clear) // Ensure Section background is clear
                    
                    // Section 3: Calendar
                    Section {
                        VStack(spacing: 8) {
                            CalendarView(
                                transactions: transactionRepo.transactions,
                                totalBudget: totalBudget, 
                                monthlyIncome: monthlyIncome,
                                signupDate: appState.userSignupDate
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .onAppear {
                            GamificationManager.shared.completeMission(id: "insight_master")
                        }
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
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(recurringRepo.recurringTransactions) { recurring in
                                RecurringTransactionCard(
                                    transaction: recurring,
                                    onDelete: { deleteRecurringTransaction(recurring) },
                                    onEdit: { recurringToEdit = recurring }
                                )
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
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
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(budgetRepo.budgets.filter { $0.category != "Income" }) { budget in
                                HStack(spacing: AppSpacing.element) {
                                    Image(systemName: budget.icon)
                                        .frame(width: 48, height: 48)
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
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        HapticManager.shared.heavy()
                                        deleteBudget(budget)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        HapticManager.shared.medium()
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
                    checkForNewMonth()
                }
                .onChange(of: appState.currentUserId) { _, newUserId in
                    if !newUserId.isEmpty {
                        checkForNewMonth()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddSavingGoal) {
                AddSavingGoalView(onSave: { goal in
                    addSavingGoal(goal)
                })
            }
            .sheet(item: $goalToEdit) { goal in
                AddSavingGoalView(goalToEdit: goal, onSave: { updatedGoal in
                    updateSavingGoal(goal, with: updatedGoal)
                })
            }
            .sheet(isPresented: $showAddRecurring) {
                AddRecurringTransactionView(onSave: { transaction in
                    addRecurringTransaction(transaction)
                })
            }
            .sheet(item: $recurringToEdit) { transaction in
                AddRecurringTransactionView(recurringToEdit: transaction, onSave: { updatedTransaction in
                    updateRecurringTransaction(transaction, with: updatedTransaction)
                })
            }
            .sheet(isPresented: $showAddBudget) {
                AddBudgetView(onSave: { budget in
                    addBudget(budget)
                })
            }
            .sheet(item: $budgetToEdit) { budget in
                AddBudgetView(budgetToEdit: budget, onSave: { updatedBudget in
                    updateBudget(budget, with: updatedBudget)
                })
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
                .presentationBackground(Color.backgroundPrimary)
                .presentationBackground(Color.backgroundPrimary)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchTab"))) { notification in
                if let action = notification.userInfo?["action"] as? String {
                    handleWalletAction(action)
                }
            }
        }
        .errorBanner(errorState)
        .undoableBanner(undoState)
    }
    
    private func handleWalletAction(_ action: String) {
        // Reset sheets
        showAddSavingGoal = false
        showAddRecurring = false
        showAddBudget = false
        
        switch action {
        case "add_budget", "add_category":
            showAddBudget = true
        case "add_goal":
            showAddSavingGoal = true
        case "add_recurring":
            showAddRecurring = true
        case "scroll_to_calendar":
            // Scroll logic would go here if we had a ScrollViewProxy
            break
        default:
            break
        }
    }

    
    
    private func calculateAllTimeSavingsPool() -> Double {
        // Find signup date: AppState or fallback to first transaction
        let signupDate: Date
        if let appDate = appState.userSignupDate {
            signupDate = appDate
        } else if let firstTransaction = transactionRepo.transactions.last?.date {
            signupDate = firstTransaction
        } else {
            return 0
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var current = calendar.startOfDay(for: signupDate)
        
        var totalPool = 0.0
        
        // Sum up the surplus for every day since signup
        while current <= today {
            totalPool += calculateSurplus(for: current)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDay
        }
        
        return max(0, totalPool)
    }
    
    private func calculateSurplus(for date: Date) -> Double {
        let calendar = Calendar.current
        
        // 1. Get the number of days in this specific month
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return 0 }
        let daysInMonthCount = Double(range.count)
        
        // 2. Determine the Daily Allowance (The "Grind" Budget)
        let dailyAllowance = totalBudget / daysInMonthCount
        
        // 3. Calculate "Manual" Flow for this specific day
        let dailyTransactions = transactionRepo.transactions.filter { 
            calendar.isDate($0.date, inSameDayAs: date) 
        }
        
        let dailySpent = dailyTransactions
            .filter { $0.type == "expense" }
            .reduce(0) { $0 + abs($1.amount) }
            
        let dailyManualIncome = dailyTransactions
            .filter { transaction in
                guard transaction.type == "income" else { return false }
                // Exclude auto-generated recurring income to prevent double counting with "Vault" logic
                if transaction.source == "recurring" { return false }
                if let note = transaction.note, note.contains("Recurring:") { return false }
                return true
            }
            .reduce(0) { $0 + $1.amount }
            
        // 4. Base Surplus (The Simulation Result)
        var surplus = dailyAllowance - dailySpent + dailyManualIncome
        
        // 5. The Reconciliation (The Vault Reveal - Only on the last day of a month)
        if let monthInterval = calendar.dateInterval(of: .month, for: date),
           let endOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
           calendar.isDate(date, inSameDayAs: endOfMonth) {
            
            // Add the unallocated Recurring Income (The Vault)
            let vaultSavings = monthlyIncome - totalBudget
            surplus += vaultSavings
        }
        
        return surplus
    }
    
    private func calculateGoalAllocation(for index: Int, in goals: [FirestoreModels.SavingGoal], pool: Double) -> Double {
        var remainingPool = pool
        for i in 0..<goals.count {
            let goal = goals[i]
            let needed = goal.targetAmount
            let allocation = min(remainingPool, needed)
            let clamped = max(0, min(allocation, goal.targetAmount - goal.currentAmount))
            
            if i == index {
                return clamped
            }
            
            remainingPool -= clamped
            if remainingPool <= 0 { break }
        }
        return 0
    }
    
    private func deleteSavingGoal(_ goal: FirestoreModels.SavingGoal) {
        guard let id = goal.id else { return }
        hiddenItemIds.insert(id)
        HapticManager.shared.heavy()
        
        undoState.schedule(
            label: "Goal deleted",
            onUndo: { [self] in
                hiddenItemIds.remove(id)
            },
            onConfirm: { [self] in
                hiddenItemIds.remove(id)
                Task {
                    do {
                        try await savingGoalRepo.deleteSavingGoal(id: id)
                    } catch {
                        errorState.show("Failed to delete saving goal")
                    }
                }
            }
        )
    }
    
    private func deleteRecurringTransaction(_ transaction: FirestoreModels.RecurringTransaction) {
        guard let id = transaction.id else { return }
        hiddenItemIds.insert(id)
        HapticManager.shared.heavy()
        
        undoState.schedule(
            label: "Recurring item deleted",
            onUndo: { [self] in
                hiddenItemIds.remove(id)
            },
            onConfirm: { [self] in
                hiddenItemIds.remove(id)
                Task {
                    do {
                        try await recurringRepo.deleteRecurringTransaction(id: id)
                    } catch {
                        errorState.show("Failed to delete recurring transaction")
                    }
                }
            }
        )
    }
    
    private func deleteBudget(_ budget: FirestoreModels.CategoryBudget) {
        let id = budget.id ?? UUID().uuidString
        hiddenItemIds.insert(id)
        HapticManager.shared.heavy()
        
        undoState.schedule(
            label: "Budget deleted",
            onUndo: { [self] in
                hiddenItemIds.remove(id)
            },
            onConfirm: { [self] in
                hiddenItemIds.remove(id)
                Task {
                    do {
                        try await budgetRepo.deleteBudget(budget)
                    } catch {
                        errorState.show("Failed to delete budget")
                    }
                }
            }
        )
    }
    
    private func moveSavingGoals(from source: IndexSet, to destination: Int) {
        var updatedGoals = savingGoalRepo.savingGoals
        updatedGoals.move(fromOffsets: source, toOffset: destination)
        
        // Wrap in withAnimation for a smooth native slide effect
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            savingGoalRepo.savingGoals = updatedGoals
        }
        
        // Sync to backend
        savingGoalRepo.reorderSavingGoals(updatedGoals)
    }
    
    
    private func addSavingGoal(_ goal: SavingGoalFormData) {
        Task {
            do {
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
                try await savingGoalRepo.addSavingGoal(firestoreGoal)
            } catch {
                errorState.show("Failed to save goal")
            }
        }
    }
    
    private func updateSavingGoal(_ entity: FirestoreModels.SavingGoal, with goal: SavingGoalFormData) {
        var updatedGoal = entity
        updatedGoal.name = goal.name
        updatedGoal.targetAmount = goal.targetAmount
        updatedGoal.currentAmount = goal.currentAmount
        updatedGoal.targetDate = goal.targetDate
        updatedGoal.icon = goal.icon
        updatedGoal.colorHex = goal.color.toHex() ?? "#000000"
        
        Task {
            do {
                try await savingGoalRepo.updateSavingGoal(updatedGoal)
            } catch {
                errorState.show("Failed to update goal")
            }
        }
    }
    
    private func addRecurringTransaction(_ transaction: RecurringTransactionFormData) {
        Task {
            do {
                let firestoreTransaction = FirestoreModels.RecurringTransaction(
                    name: transaction.name,
                    amount: transaction.amount,
                    frequency: transaction.frequency,
                    startDate: transaction.startDate,
                    icon: transaction.icon,
                    colorHex: transaction.color.toHex() ?? "#000000",
                    note: transaction.notes,
                    type: transaction.type,
                    userId: appState.currentUserId,
                    createdAt: Date()
                )
                try await recurringRepo.addRecurringTransaction(firestoreTransaction)
            } catch {
                errorState.show("Failed to save recurring transaction")
            }
        }
    }
    
    private func updateRecurringTransaction(_ entity: FirestoreModels.RecurringTransaction, with transaction: RecurringTransactionFormData) {
        var updatedTransaction = entity
        updatedTransaction.name = transaction.name
        updatedTransaction.amount = transaction.amount
        updatedTransaction.frequency = transaction.frequency
        updatedTransaction.icon = transaction.icon
        updatedTransaction.colorHex = transaction.color.toHex() ?? "#000000"
        updatedTransaction.note = transaction.notes
        updatedTransaction.startDate = transaction.startDate
        updatedTransaction.type = transaction.type
        
        Task {
            do {
                try await recurringRepo.updateRecurringTransaction(updatedTransaction)
            } catch {
                errorState.show("Failed to update recurring transaction")
            }
        }
    }
    
    private func addBudget(_ budget: BudgetFormData) {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        
        Task {
            do {
                let firestoreBudget = FirestoreModels.CategoryBudget(
                    category: budget.category,
                    totalAmount: budget.totalAmount,
                    icon: budget.icon,
                    colorHex: budget.color.toHex() ?? "#000000",
                    frequency: budget.frequency,
                    type: budget.type,
                    userId: appState.currentUserId,
                    monthStartDate: startOfMonth,
                    createdAt: Date()
                )
                try await budgetRepo.addBudget(firestoreBudget)
            } catch {
                errorState.show("Failed to save budget")
            }
        }
    }
    
    private func updateBudget(_ entity: FirestoreModels.CategoryBudget, with budget: BudgetFormData) {
        var updatedBudget = entity
        updatedBudget.category = budget.category
        updatedBudget.totalAmount = budget.totalAmount
        updatedBudget.icon = budget.icon
        updatedBudget.colorHex = budget.color.toHex() ?? "#000000"
        updatedBudget.frequency = budget.frequency
        updatedBudget.type = budget.type
            
        Task {
            do {
                try await budgetRepo.updateBudget(updatedBudget)
            } catch {
                errorState.show("Failed to update budget")
            }
        }
    }
    
    private func checkForNewMonth() {
        // Legacy: Budgets are now permanent and reset based on frequency
    }

}






#Preview {
    WalletView()
        .environmentObject(AppState.shared)
}
