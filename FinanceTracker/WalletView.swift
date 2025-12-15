import SwiftUI

struct WalletView: View {
    @State private var showAddGoal = false
    @State private var showAddRecurring = false
    @State private var showAddBudget = false
    
    @State private var goalToEdit: SavingGoal?
    @State private var recurringToEdit: RecurringTransaction?
    @State private var budgetToEdit: Budget?
    
    @State private var savingGoals: [SavingGoal] = [
        SavingGoal(name: "New Car", currentAmount: 5000, targetAmount: 20000, icon: "car.fill", color: .blue, targetDate: Date())
    ]
    
    @State private var recurringTransactions: [RecurringTransaction] = [
        RecurringTransaction(name: "Rent", amount: 1200, icon: "house.fill", color: .orange, frequency: "Monthly")
    ]
    
    @State private var budgets: [Budget] = [
        Budget(category: "Groceries", remainingAmount: 400, totalAmount: 600, icon: "cart.fill", color: .green, frequency: "Monthly")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                List {
                    // Section 1: Total Balance
                    Section {
                        VStack(spacing: 8) {
                            Text("Total Balance")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text("$12,450.00")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.bottom, 10)
                    }
                    
                    // Section 2: Saving Goals
                    Section(header: 
                        HStack {
                            Text("Saving Goals").font(.title2).fontWeight(.bold).foregroundColor(.primary)
                            Spacer()
                            Button(action: { 
                                goalToEdit = nil
                                showAddGoal = true 
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.bottom, 8)
                    ) {
                        ForEach(savingGoals) { goal in
                            HStack {
                                Image(systemName: goal.icon)
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(goal.color)
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
                            .cornerRadius(16)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.bottom, 8)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if let index = savingGoals.firstIndex(where: { $0.id == goal.id }) {
                                        savingGoals.remove(at: index)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    goalToEdit = goal
                                    showAddGoal = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    
                    // Section 3: Calendar
                    Section {
                        CalendarView()
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 10)
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
                        .padding(.bottom, 8)
                    ) {
                        ForEach(recurringTransactions) { recurring in
                            HStack {
                                Image(systemName: recurring.icon)
                                    .frame(width: 40, height: 40)
                                    .background(recurring.color.opacity(0.2))
                                    .foregroundColor(recurring.color)
                                    .clipShape(Circle())
                                Text(recurring.name)
                                    .font(.headline)
                                Spacer()
                                Text("$\(Int(recurring.amount))/\(recurring.frequency == "Monthly" ? "mo" : "yr")")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.bottom, 8)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if let index = recurringTransactions.firstIndex(where: { $0.id == recurring.id }) {
                                        recurringTransactions.remove(at: index)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    recurringToEdit = recurring
                                    showAddRecurring = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
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
                        .padding(.bottom, 8)
                    ) {
                        ForEach(budgets) { budget in
                            HStack {
                                Image(systemName: budget.icon)
                                    .frame(width: 40, height: 40)
                                    .background(budget.color.opacity(0.2))
                                    .foregroundColor(budget.color)
                                    .clipShape(Circle())
                                Text(budget.category)
                                    .font(.headline)
                                Spacer()
                                Text("$\(Int(budget.remainingAmount)) left")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.bottom, 8)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if let index = budgets.firstIndex(where: { $0.id == budget.id }) {
                                        budgets.remove(at: index)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    budgetToEdit = budget
                                    showAddBudget = true
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
                .navigationTitle("Wallet")
            }
            .sheet(isPresented: $showAddGoal) {
                AddSavingGoalView(goalToEdit: goalToEdit, onSave: { updatedGoal in
                    if let index = savingGoals.firstIndex(where: { $0.id == updatedGoal.id }) {
                        savingGoals[index] = updatedGoal
                    } else {
                        savingGoals.append(updatedGoal)
                    }
                })
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddRecurring) {
                AddRecurringTransactionView(recurringToEdit: recurringToEdit, onSave: { updatedRecurring in
                    if let index = recurringTransactions.firstIndex(where: { $0.id == updatedRecurring.id }) {
                        recurringTransactions[index] = updatedRecurring
                    } else {
                        recurringTransactions.append(updatedRecurring)
                    }
                })
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddBudget) {
                AddBudgetView(budgetToEdit: budgetToEdit, onSave: { updatedBudget in
                    if let index = budgets.firstIndex(where: { $0.id == updatedBudget.id }) {
                        budgets[index] = updatedBudget
                    } else {
                        budgets.append(updatedBudget)
                    }
                })
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}


#Preview {
    WalletView()
}
