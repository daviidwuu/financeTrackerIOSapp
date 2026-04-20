import SwiftUI
import Combine

struct SelectedCalendarDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct WalletView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var savingGoalRepo: SavingGoalRepository
    @EnvironmentObject var recurringRepo: RecurringTransactionRepository
    @EnvironmentObject var budgetRepo: BudgetRepository
    @EnvironmentObject var transactionRepo: TransactionRepository

    @StateObject private var viewModel = WalletViewModel()

    @State private var showAddSavingGoal = false
    @State private var showAddRecurring = false
    @State private var showAddBudget = false
    @State private var errorState = ErrorState()
    @State private var undoState = UndoState()
    @State private var hiddenItemIds: Set<String> = []

    @State private var calendarMonth = Date()
    @State private var goalToEdit: FirestoreModels.SavingGoal?
    @State private var recurringToEdit: FirestoreModels.RecurringTransaction?
    @State private var recurringToView: FirestoreModels.RecurringTransaction?
    @State private var budgetToEdit: FirestoreModels.CategoryBudget?
    @State private var showEditBalance = false
    @State private var spendingCategoryFilter: String? = nil
    @State private var showSpendingTransactions = false
    @State private var calendarSelectedDate: SelectedCalendarDate? = nil

    @AppStorage("initialBalance") private var initialBalance = 0.0

    var totalBalance: Double {
        viewModel.totalBalance(initialBalance: initialBalance, aggregatedIncome: appState.aggregatedIncome, aggregatedExpense: appState.aggregatedExpense)
    }

    var totalBudget: Double {
        viewModel.totalBudget(budgets: budgetRepo.budgets)
    }

    var currentMonthIncome: Double {
        WalletLogic.calculateCurrentMonthIncome(transactions: transactionRepo.currentMonthTransactions)
    }

    var totalExpense: Double {
        WalletLogic.calculateCurrentMonthExpense(transactions: transactionRepo.currentMonthTransactions)
    }

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
                if !appState.currentUserId.isEmpty {
                    transactionRepo.setCalendarMonth(calendarMonth)
                }
            }
            .onChange(of: calendarMonth) { _, newMonth in
                if !appState.currentUserId.isEmpty {
                    transactionRepo.setCalendarMonth(newMonth)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                List {
                    ScrollOffsetTracker()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

                    Color.clear.frame(height: 0)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    // Net Worth card
                    Section(header:
                        Text("All Time")
                            .font(.title2).fontWeight(.bold).foregroundColor(.primary)
                            .textCase(nil)
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Net Worth").font(.subheadline).foregroundColor(.secondary)
                                Text("$\(String(format: "%.2f", totalBalance))")
                                    .font(AppTypography.sectionHeader)
                                    .foregroundColor(totalBalance >= 0 ? .primary : .functionalError)
                            }
                            Spacer()
                            TrendGraph(
                                points: viewModel.netWorthTrendPoints(allTransactions: transactionRepo.allTransactions, initialBalance: initialBalance),
                                color: totalBalance >= 0 ? .primary : .functionalError
                            )
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
                        .onTapGesture { HapticManager.shared.light(); showEditBalance.toggle() }
                    }

                    WalletSavingGoalsSection(
                        hiddenItemIds: hiddenItemIds,
                        goalAllocation: { index, goals in viewModel.goalAllocation(for: index, in: goals) },
                        onAdd: { goalToEdit = nil; showAddSavingGoal = true },
                        onEdit: { goal in goalToEdit = goal },
                        onDelete: deleteSavingGoal,
                        onMove: moveSavingGoals
                    )

                    Section {
                        NativeAdView()
                            .listRowInsets(EdgeInsets(top: AppSpacing.compact, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listRowBackground(Color.clear)

                    calendarSection

                    WalletRecurringSection(
                        hiddenItemIds: hiddenItemIds,
                        onAdd: { recurringToEdit = nil; showAddRecurring = true },
                        onEdit: { recurring in recurringToEdit = recurring },
                        onDelete: deleteRecurringTransaction,
                        onView: { recurring in recurringToView = recurring }
                    )

                    // Breakdown section
                    Section(header:
                        HStack {
                            Text("Breakdown").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                            Spacer()
                            HStack(spacing: AppSpacing.element) {
                                Button {
                                    HapticManager.shared.light()
                                    if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: viewModel.breakdownMonth) {
                                        viewModel.breakdownMonth = newMonth
                                    }
                                } label: {
                                    Image(systemName: "chevron.left").font(.caption.bold()).foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)

                                Text(viewModel.breakdownMonth, format: .dateTime.month(.wide))
                                    .font(.subheadline).foregroundColor(.secondary)

                                Button {
                                    HapticManager.shared.light()
                                    if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: viewModel.breakdownMonth) {
                                        viewModel.breakdownMonth = newMonth
                                    }
                                } label: {
                                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(!viewModel.canGoToNextMonth(from: viewModel.breakdownMonth))
                                .opacity(viewModel.canGoToNextMonth(from: viewModel.breakdownMonth) ? 1.0 : 0.3)
                            }
                        }
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                    ) {
                        SpendingPieChartView(
                            transactions: viewModel.breakdownTransactions(allTransactions: transactionRepo.allTransactions),
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

                    WalletBudgetsSection(
                        hiddenItemIds: hiddenItemIds,
                        onAdd: { budgetToEdit = nil; showAddBudget = true },
                        onEdit: { budget in budgetToEdit = budget },
                        onDelete: deleteBudget
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(.top, -20)
            }
            .overlayHeader(.root(title: "Wallet"))
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddSavingGoal) {
                AddSavingGoalView(onSave: { goal in
                    viewModel.addSavingGoal(goal, userId: appState.currentUserId, repo: savingGoalRepo, errorState: errorState)
                })
            }
            .sheet(item: $goalToEdit) { goal in
                AddSavingGoalView(goalToEdit: goal, onSave: { updatedGoal in
                    viewModel.updateSavingGoal(goal, with: updatedGoal, repo: savingGoalRepo, errorState: errorState)
                })
            }
            .sheet(isPresented: $showAddRecurring) {
                AddRecurringTransactionView(onSave: { transaction in
                    viewModel.addRecurringTransaction(transaction, userId: appState.currentUserId, repo: recurringRepo, errorState: errorState)
                })
            }
            .sheet(item: $recurringToEdit) { transaction in
                AddRecurringTransactionView(recurringToEdit: transaction, onSave: { updatedTransaction in
                    viewModel.updateRecurringTransaction(transaction, with: updatedTransaction, repo: recurringRepo, errorState: errorState)
                })
            }
            .sheet(item: $recurringToView) { transaction in
                RecurringTransactionDetailView(
                    transaction: transaction,
                    onSave: { updatedRecurring, formData in
                        viewModel.updateRecurringTransaction(transaction, with: formData, repo: recurringRepo, errorState: errorState)
                        recurringToView = updatedRecurring
                    },
                    onDelete: { deleteRecurringTransaction(transaction) }
                )
            }
            .sheet(isPresented: $showAddBudget) {
                AddBudgetView(onSave: { budget in
                    viewModel.addBudget(budget, userId: appState.currentUserId, repo: budgetRepo, errorState: errorState)
                })
            }
            .sheet(item: $budgetToEdit) { budget in
                AddBudgetView(budgetToEdit: budget, onSave: { updatedBudget in
                    viewModel.updateBudget(budget, with: updatedBudget, repo: budgetRepo, errorState: errorState)
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
                appState.profileState.$userSignupDate
            )
        ) { _ in
            viewModel.refreshSavingsPool(
                signupDate: appState.userSignupDate,
                allTransactions: transactionRepo.allTransactions,
                budgets: budgetRepo.budgets
            )
        }
    }

    // MARK: - Wallet Action

    private func handleWalletAction(_ action: String) {
        showAddBudget = false
        showAddSavingGoal = false
        showAddRecurring = false
        switch action {
        case "add_budget", "add_category": showAddBudget = true
        case "add_goal": showAddSavingGoal = true
        case "add_recurring": showAddRecurring = true
        default: break
        }
    }

    // MARK: - Delete (optimistic UI — stays in view to capture @State)

    private func deleteSavingGoal(_ goal: FirestoreModels.SavingGoal) {
        guard let id = goal.id else { return }
        hiddenItemIds.insert(id)
        HapticManager.shared.heavy()
        undoState.schedule(
            label: "Goal deleted",
            onUndo: { hiddenItemIds.remove(id) },
            onConfirm: {
                hiddenItemIds.remove(id)
                Task {
                    do { try await savingGoalRepo.deleteSavingGoal(id: id) }
                    catch { errorState.show("Failed to delete saving goal") }
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
            onUndo: { hiddenItemIds.remove(id) },
            onConfirm: {
                hiddenItemIds.remove(id)
                Task {
                    do { try await recurringRepo.deleteRecurringTransaction(id: id) }
                    catch { errorState.show("Failed to delete recurring transaction") }
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
            onUndo: { hiddenItemIds.remove(id) },
            onConfirm: {
                hiddenItemIds.remove(id)
                Task {
                    do { try await budgetRepo.deleteBudget(budget) }
                    catch { errorState.show("Failed to delete budget") }
                }
            }
        )
    }

    // MARK: - Move

    private func moveSavingGoals(from source: IndexSet, to destination: Int) {
        var visible = savingGoalRepo.savingGoals.filter { !hiddenItemIds.contains($0.id ?? "") }
        let hidden = savingGoalRepo.savingGoals.filter { hiddenItemIds.contains($0.id ?? "") }
        visible.move(fromOffsets: source, toOffset: destination)
        let updated = visible + hidden
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            savingGoalRepo.savingGoals = updated
        }
        Task { try? await savingGoalRepo.reorderSavingGoals(updated) }
    }
}

#Preview {
    WalletView()
        .environmentObject(AppState.shared)
}
