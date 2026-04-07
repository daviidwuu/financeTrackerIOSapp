import SwiftUI
import Combine

struct SelectedCalendarDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct WalletView: View {
    @EnvironmentObject var appState: AppState
    
    // Repositories moved to AppState
    @EnvironmentObject var savingGoalRepo: SavingGoalRepository
    @EnvironmentObject var recurringRepo: RecurringTransactionRepository
    @EnvironmentObject var budgetRepo: BudgetRepository
    @EnvironmentObject var transactionRepo: TransactionRepository
    
    @State private var showAddSavingGoal = false
    @State private var showAddRecurring = false
    @State private var showAddBudget = false
    @State private var errorState = ErrorState()
    @State private var undoState = UndoState()
    @State private var hiddenItemIds: Set<String> = []
    
    // Binding state for CalendarView
    @State private var calendarMonth = Date()
    
    @State private var goalToEdit: FirestoreModels.SavingGoal?
    @State private var recurringToEdit: FirestoreModels.RecurringTransaction?
    @State private var recurringToView: FirestoreModels.RecurringTransaction? // Added for detail view modal
    @State private var budgetToEdit: FirestoreModels.CategoryBudget?
    @State private var showEditBalance = false
    @State private var balanceInput = ""
    @State private var spendingCategoryFilter: String? = nil
    @State private var showSpendingTransactions = false
    @State private var calendarSelectedDate: SelectedCalendarDate? = nil
    
    // Monthly breakdown selection
    @State private var breakdownMonth = Date()
    
    @AppStorage("initialBalance") private var initialBalance = 0.0

    // Cached savings pool — recomputed only when allTransactions changes, not on every render
    @State private var savingsPool: Double = 0
    
    var monthlyIncome: Double {
        WalletLogic.calculateMonthlyIncome(recurringTransactions: recurringRepo.recurringTransactions)
    }
    
    @State private var showDetails = false
    
    var totalBalance: Double {
        WalletLogic.calculateTotalBalance(initialBalance: initialBalance, aggregatedIncome: appState.aggregatedIncome, aggregatedExpense: appState.aggregatedExpense)
    }
    
    var totalBudget: Double {
        WalletLogic.calculateTotalBudget(budgets: budgetRepo.budgets)
    }
    
    var incomeLeft: Double {
        WalletLogic.calculateIncomeLeft(monthlyIncome: monthlyIncome, transactions: transactionRepo.currentMonthTransactions)
    }
    
    var currentMonthIncome: Double {
        WalletLogic.calculateCurrentMonthIncome(transactions: transactionRepo.currentMonthTransactions)
    }
    
    var totalExpense: Double {
        WalletLogic.calculateCurrentMonthExpense(transactions: transactionRepo.currentMonthTransactions)
    }
    
    var netCashFlow: Double {
        WalletLogic.calculateNetCashFlow(transactions: transactionRepo.currentMonthTransactions)
    }
    
    private var netWorthTrendPoints: [Double] {
        guard !transactionRepo.allTransactions.isEmpty else { return [0, 1] }
        
        let sortedTxs = transactionRepo.allTransactions.sorted { $0.date > $1.date }
        var points: [Double] = []
        
        let calendar = Calendar.current
        let today = Date()
        
        for i in (0..<6).reversed() { // Plot last 6 months
            if let monthDate = calendar.date(byAdding: .month, value: -i, to: today) {
                // Find balance up to the end of this monthDate
                let startOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.date(byAdding: .month, value: 1, to: monthDate)!))!
                
                var balance = initialBalance
                for tx in transactionRepo.allTransactions {
                    if tx.date < startOfNextMonth {
                        if tx.type == "income" || tx.type == "settlement" {
                            balance += abs(tx.amount)
                        } else {
                            balance -= abs(tx.amount)
                        }
                    }
                }
                points.append(balance)
            }
        }
        
        if let first = points.first, points.allSatisfy({ $0 == first }) {
            return [first, first + 1]
        }
        return points
    }
    
    private func canGoToNextMonth(from date: Date) -> Bool {
        let calendar = Calendar.current
        let currentMonth = calendar.dateComponents([.year, .month], from: Date())
        let dateMonth = calendar.dateComponents([.year, .month], from: date)
        
        if let currentYear = currentMonth.year, let currentMonthNum = currentMonth.month,
           let dateYear = dateMonth.year, let dateMonthNum = dateMonth.month {
            if dateYear < currentYear { return true }
            if dateYear == currentYear && dateMonthNum < currentMonthNum { return true }
        }
        return false
    }

    var breakdownTransactions: [FirestoreModels.TransactionModel] {
        let calendar = Calendar.current
        return transactionRepo.allTransactions.filter { 
            calendar.isDate($0.date, equalTo: breakdownMonth, toGranularity: .month) 
        }
    }
    
    // Extracted Calendar Section to help compiler check types
    private var calendarSection: some View {
        Section(header:
            Text("Calendar").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                .textCase(nil)
                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
        ) {
            VStack(spacing: 8) {
                CalendarView(
                    currentDate: $calendarMonth,
                    transactions: transactionRepo.calendarTransactions,
                    categories: budgetRepo.budgets,
                    totalBudget: totalBudget,
                    signupDate: appState.userSignupDate,
                    onDateTapped: { date in
                        calendarSelectedDate = SelectedCalendarDate(date: date)
                    }
                )
            }
            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .onAppear {
                GamificationManager.shared.completeMission(id: "insight_master")
                let userId = appState.currentUserId
                if !userId.isEmpty {
                    transactionRepo.setCalendarMonth(calendarMonth)
                }
            }
            .onChange(of: calendarMonth) { _, newMonth in
                let userId = appState.currentUserId
                if !userId.isEmpty {
                    transactionRepo.setCalendarMonth(newMonth)
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.backgroundPrimary
                    .ignoresSafeArea()

                List {
                    // Scroll offset tracker + spacer for fixed header
                    ScrollOffsetTracker()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

                    Color.clear.frame(height: 0)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    // Section 1: Financial Overview (Net Worth Card)
                    Section(header:
                        Text("All Time")
                            .font(.title2).fontWeight(.bold).foregroundColor(.primary)
                            .textCase(nil)
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Net Worth")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("$\(String(format: "%.2f", totalBalance))")
                                    .font(AppTypography.sectionHeader)
                                    .foregroundColor(totalBalance >= 0 ? .primary : .functionalError)
                            }
                            
                            Spacer()
                            
                            TrendGraph(points: netWorthTrendPoints, color: totalBalance >= 0 ? .primary : .functionalError)
                                .frame(width: 60, height: 30)
                                .padding(.trailing, 8)
                        }
                        .padding(AppSpacing.margin)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
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
                            let sortedGoals = savingGoalRepo.savingGoals.filter { goal in
                                guard let id = goal.id else { return true }
                                return !hiddenItemIds.contains(id)
                            }
                            let goalAllocations = sortedGoals.enumerated().map { index, goal in
                                (goal: goal, amount: calculateGoalAllocation(for: index, in: sortedGoals, pool: savingsPool))
                            }

                            ForEach(goalAllocations, id: \.goal.id) { item in
                                let goal = item.goal
                                let currentAmount = item.amount
                                
                                HStack(spacing: AppSpacing.element) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: goal.colorHex).opacity(0.15))
                                            .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                                        Image(systemName: goal.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(Color(hex: goal.colorHex))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                                        Text(goal.name)
                                            .font(.headline)
                                        Text("$\(Int(currentAmount)) / $\(Int(goal.targetAmount))")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.secondary)
                                        
                                        HStack(spacing: AppSpacing.micro) {
                                            Image(systemName: "calendar")
                                                .font(.caption2)
                                            Text("Target: \(goal.targetDate.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(Color.tertiaryLabel)
                                    }
                                    
                                    Spacer()
                                    
                                    let percentage = goal.targetAmount > 0 ? Int((currentAmount / goal.targetAmount) * 100) : (currentAmount > 0 ? 100 : 0)
                                    Text("\(percentage)%")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                .padding()
                                .background(Color.cardBackground)
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
                                    .tint(Color.functionalError)
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
                    
                    // [NEW] Native Ad
                    Section {
                        NativeAdView()
                            .listRowInsets(EdgeInsets(top: AppSpacing.compact, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listRowBackground(Color.clear)
                    
                    // Section 3: Calendar
                    calendarSection
                    
                    // Section 4: Recurring Transactions
                    Section(header:
                        HStack {
                            Text("Recurring").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                            Spacer()
                            Button(action: { HapticManager.shared.light();  
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
                            ForEach(recurringRepo.recurringTransactions.filter { recurring in
                                guard let id = recurring.id else { return true }
                                return !hiddenItemIds.contains(id)
                            }) { recurring in
                                Button(action: {
                                    HapticManager.shared.light()
                                    recurringToView = recurring
                                }) {
                                    RecurringTransactionCard(
                                        transaction: recurring,
                                        onDelete: { deleteRecurringTransaction(recurring) },
                                        onEdit: { recurringToEdit = recurring }
                                    )
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            } 
                        }
                    }
                    .listRowBackground(Color.clear)

                    // Section 5: Spending Pie Chart
                    Section(header:
                        HStack {
                            Text("Breakdown").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                            Spacer()
                            HStack(spacing: AppSpacing.element) {
                                Button(action: {
                                    HapticManager.shared.light()
                                    if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: breakdownMonth) {
                                        breakdownMonth = newMonth
                                    }
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)

                                Text(breakdownMonth, format: .dateTime.month(.wide))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    HapticManager.shared.light()
                                    if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: breakdownMonth) {
                                        breakdownMonth = newMonth
                                    }
                                }) {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canGoToNextMonth(from: breakdownMonth))
                                .opacity(canGoToNextMonth(from: breakdownMonth) ? 1.0 : 0.3)
                            }
                        }
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                    ) {
                        SpendingPieChartView(
                            transactions: breakdownTransactions,
                            categories: budgetRepo.budgets,
                            onCategoryTapped: { categoryName in
                                spendingCategoryFilter = categoryName
                                showSpendingTransactions = true
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listRowBackground(Color.clear)

                    // Section 6: Budgets
                    Section(header:
                        HStack {
                            Text("Budgets").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                            Spacer()
                            Button(action: { HapticManager.shared.light();  
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
                            ForEach(budgetRepo.budgets.filter { budget in
                                budget.category != "Income" && !hiddenItemIds.contains(budget.id ?? "")
                            }) { budget in
                                HStack(spacing: AppSpacing.element) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: budget.colorHex).opacity(0.15))
                                            .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                                        Image(systemName: budget.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(Color(hex: budget.colorHex))
                                    }
                                    Text(budget.category)
                                        .font(.headline)
                                    Spacer()
                                    if budget.totalAmount == 0 {
                                        // Infinite Budget: Show "Spent" instead of "Left"
                                        // remaining = 0 - spent => spent = -remaining
                                        let spent = abs(budget.remainingAmount(transactions: transactionRepo.allTransactions))
                                        Text("$\(Int(spent)) spent")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("$\(Int(budget.remainingAmount(transactions: transactionRepo.allTransactions))) left")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color.cardBackground)
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
                                    .tint(Color.functionalError)
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
                .padding(.top, -20)
                .onAppear {
                    checkForNewMonth()
                }
                .onChange(of: appState.currentUserId) { _, newUserId in
                    if !newUserId.isEmpty {
                        checkForNewMonth()
                    }
                }
            }
            .overlayHeader(.root(title: "Wallet"))
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
            .sheet(item: $recurringToView) { transaction in
                RecurringTransactionDetailView(
                    transaction: transaction,
                    onSave: { updatedRecurring, formData in
                        updateRecurringTransaction(transaction, with: formData)
                        recurringToView = updatedRecurring
                    },
                    onDelete: {
                        deleteRecurringTransaction(transaction)
                    }
                )
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
                    totalBalance: totalBalance,
                    aggregatedIncome: appState.aggregatedIncome,
                    aggregatedExpense: appState.aggregatedExpense,
                    currentMonthIncome: currentMonthIncome,
                    currentMonthExpense: totalExpense,
                    totalBudget: totalBudget
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.backgroundPrimary)
                .presentationBackground(Color.backgroundPrimary)
            }
            .sheet(isPresented: $showSpendingTransactions) {
                AllTransactionsView(
                    transactionRepo: transactionRepo,
                    budgetRepo: budgetRepo,
                    initialCategory: spendingCategoryFilter
                )
                .environmentObject(appState)
                .presentationBackground(Color.backgroundPrimary)
            }
            .sheet(item: $calendarSelectedDate) { item in
                AllTransactionsView(
                    transactionRepo: transactionRepo,
                    budgetRepo: budgetRepo,
                    initialDate: item.date
                )
                .environmentObject(appState)
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
        .onReceive(
            Publishers.CombineLatest3(
                transactionRepo.$allTransactions,
                budgetRepo.$budgets,
                appState.$userSignupDate
            )
        ) { _ in
            savingsPool = calculateAllTimeSavingsPool()
        }
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
        WalletLogic.calculateAllTimeSavingsPool(
            signupDate: appState.userSignupDate,
            transactions: transactionRepo.allTransactions,
            totalBudget: totalBudget,
            categories: budgetRepo.budgets
        )
    }
    
    private func calculateGoalAllocation(for index: Int, in goals: [FirestoreModels.SavingGoal], pool: Double) -> Double {
        WalletLogic.calculateGoalAllocation(for: index, in: goals, pool: pool)
    }
    
    private func deleteSavingGoal(_ goal: FirestoreModels.SavingGoal) {
        guard let id = goal.id else { return }
        hiddenItemIds.insert(id)
        HapticManager.shared.heavy()
        
        undoState.schedule(
            label: "Goal deleted",
            onUndo: {
                hiddenItemIds.remove(id)
            },
            onConfirm: {
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
            onUndo: {
                hiddenItemIds.remove(id)
            },
            onConfirm: {
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
            onUndo: {
                hiddenItemIds.remove(id)
            },
            onConfirm: {
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
        var visibleGoals = savingGoalRepo.savingGoals.filter { goal in
            guard let id = goal.id else { return true }
            return !hiddenItemIds.contains(id)
        }
        let hiddenGoals = savingGoalRepo.savingGoals.filter { goal in
            guard let id = goal.id else { return false }
            return hiddenItemIds.contains(id)
        }
        
        visibleGoals.move(fromOffsets: source, toOffset: destination)
        let updatedGoals = visibleGoals + hiddenGoals
        
        // Wrap in withAnimation for a smooth native slide effect
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            savingGoalRepo.savingGoals = updatedGoals
        }
        
        // Sync to backend
        Task {
            try? await savingGoalRepo.reorderSavingGoals(updatedGoals)
        }
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
                    categoryId: transaction.categoryId,
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
