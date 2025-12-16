import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    var transactionToEdit: FirestoreModels.Transaction?
    var onSave: ((Transaction) -> Void)?
    
    @StateObject private var budgetRepo = BudgetRepository()
    @StateObject private var transactionRepo = TransactionRepository()
    
    @State private var currentStep = 1
    @State private var amount: String = ""
    @State private var selectedCategory: FirestoreModels.Category?
    @State private var selectedDate = Date()
    @State private var transactionNotes: String = ""
    @State private var direction: Edge = .trailing
    
    init(transactionToEdit: FirestoreModels.Transaction? = nil, onSave: ((Transaction) -> Void)? = nil) {
        self.transactionToEdit = transactionToEdit
        self.onSave = onSave
        
        if let transaction = transactionToEdit {
            _amount = State(initialValue: String(format: "%.2f", abs(transaction.amount)))
            _selectedDate = State(initialValue: transaction.date)
            _transactionNotes = State(initialValue: transaction.note ?? "")
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        if currentStep > 1 {
                            HapticManager.shared.light()
                            direction = .leading
                            withAnimation { currentStep -= 1 }
                        } else {
                            HapticManager.shared.light()
                            dismiss()
                        }
                    }) {
                        Image(systemName: currentStep > 1 ? "chevron.left" : "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    
                    Spacer()
                    
                    Text("Step \(currentStep) of 3")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.clear)
                        .frame(width: 44, height: 44)
                }
                .padding()
                
                Spacer()
                
                // Content
                ZStack(alignment: .top) {
                    currentStepView
                }
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: direction),
                    removal: .move(edge: direction == .leading ? .trailing : .leading)
                ))
                .padding(.horizontal)
                
                Spacer()
                
                // Action Button
                Button(action: {
                    if currentStep < 3 {
                        HapticManager.shared.light()
                        direction = .trailing
                        withAnimation { currentStep += 1 }
                    } else {
                        HapticManager.shared.success()
                        saveTransaction()
                    }
                }) {
                    Text(currentStep < 3 ? "Next" : (transactionToEdit != nil ? "Update Transaction" : "Save Transaction"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isStepValid ? Color.primary : Color.primary.opacity(0.3))
                        .cornerRadius(16)
                }
                .disabled(!isStepValid)
                .padding()
            }
        }
        .onAppear {
            if !appState.currentUserId.isEmpty {
                let calendar = Calendar.current
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
                budgetRepo.startListening(userId: appState.currentUserId, monthStartDate: startOfMonth)
                transactionRepo.startListening(userId: appState.currentUserId)
            }
            
            // Delay setting initial category to allow repo to load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let transaction = transactionToEdit, selectedCategory == nil {
                    // Try to find the category by name
                    if let categoryName = transaction.subtitle {
                        if let budget = budgetRepo.budgets.first(where: { $0.category == categoryName }) {
                            selectedCategory = FirestoreModels.Category(
                                id: budget.id ?? UUID().uuidString,
                                name: budget.category,
                                icon: budget.icon,
                                colorHex: budget.colorHex,
                                type: budget.type ?? "expense",
                                userId: budget.userId,
                                createdAt: budget.createdAt
                            )
                        }
                    }
                }
            }
        }
        .onDisappear {
            budgetRepo.stopListening()
            transactionRepo.stopListening()
        }
    }
    
    private func saveTransaction() {
        guard let category = selectedCategory else { return }
        
        let newTransaction = Transaction(
            title: category.name,
            subtitle: category.name,
            amount: (category.type == "income" ? "" : "-") + amount, // Use category type
            icon: category.icon,
            color: Color(hex: category.colorHex),
            date: selectedDate,
            notes: transactionNotes,
            type: category.type // Pass category type
        )
        
        if let _ = transactionToEdit {
            let updatedTransaction = newTransaction
            onSave?(updatedTransaction)
        } else {
            onSave?(newTransaction)
            
            // Send notification for new transaction
            if let amountValue = Double(amount) {
                let finalAmount = (category.type == "income") ? amountValue : -amountValue
                NotificationManager.shared.sendTransactionNotification(
                    amount: finalAmount,
                    category: category.name,
                    type: category.type
                )
            }
        }
        dismiss()
    }
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1:
            if let value = Double(amount), value > 0 {
                return true
            }
            return false
        case 2:
            return selectedCategory != nil
        case 3:
            return true
        default:
            return false
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        if currentStep == 1 {
            amountStep
        } else if currentStep == 2 {
            detailsStep
        } else {
            transactionNotesStep
        }
    }
    
    private var amountStep: some View {
        VStack(spacing: 16) {
            Text("Amount")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("0.00", text: $amount)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
        }
    }
    
    private var detailsStep: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Category")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if budgetRepo.budgets.isEmpty {
                    VStack(spacing: 12) {
                        Text("No budgets found.")
                            .foregroundColor(.secondary)
                        Text("Create a budget in the Wallet tab to see it here.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Income Categories
                            let incomeBudgets = budgetRepo.budgets.filter { ($0.type ?? "expense") == "income" }
                            if !incomeBudgets.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Income")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                        ForEach(incomeBudgets) { budget in
                                            let category = FirestoreModels.Category(
                                                id: budget.id ?? UUID().uuidString,
                                                name: budget.category,
                                                icon: budget.icon,
                                                colorHex: budget.colorHex,
                                                type: "income",
                                                userId: budget.userId,
                                                createdAt: budget.createdAt
                                            )
                                            // Income doesn't really have a "limit" in the same way, but we can show progress towards expected
                                            let currentIncome = calculateSpent(for: budget.category, type: "income")
                                            RichCategoryCard(
                                                category: category,
                                                budgetLimit: budget.totalAmount,
                                                currentAmount: currentIncome,
                                                selectedCategory: $selectedCategory
                                            )
                                        }
                                    }
                                }
                            }
                            
                            // Expense Categories
                            let expenseBudgets = budgetRepo.budgets.filter { ($0.type ?? "expense") == "expense" }
                            if !expenseBudgets.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Expense")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                        ForEach(expenseBudgets) { budget in
                                            let category = FirestoreModels.Category(
                                                id: budget.id ?? UUID().uuidString,
                                                name: budget.category,
                                                icon: budget.icon,
                                                colorHex: budget.colorHex,
                                                type: "expense",
                                                userId: budget.userId,
                                                createdAt: budget.createdAt
                                            )
                                            let spent = calculateSpent(for: budget.category, type: "expense")
                                            RichCategoryCard(
                                                category: category,
                                                budgetLimit: budget.totalAmount,
                                                currentAmount: spent,
                                                selectedCategory: $selectedCategory
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            
            if transactionToEdit != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            }
        }
    }
    
    private func calculateSpent(for categoryName: String, type: String) -> Double {
        let calendar = Calendar.current
        let currentMonthTransactions = transactionRepo.transactions.filter { transaction in
            guard transaction.subtitle == categoryName else { return false }
            return calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
        }
        return currentMonthTransactions.reduce(0) { $0 + abs($1.amount) }
    }

    struct RichCategoryCard: View {
        let category: FirestoreModels.Category
        let budgetLimit: Double
        let currentAmount: Double
        @Binding var selectedCategory: FirestoreModels.Category?
        
        var isSelected: Bool {
            selectedCategory?.name == category.name
        }
        
        var progress: Double {
            guard budgetLimit > 0 else { return 0 }
            return min(currentAmount / budgetLimit, 1.0)
        }
        
        var body: some View {
            Button(action: { selectedCategory = category }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color(hex: category.colorHex).opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: category.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: category.colorHex))
                            )
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: category.colorHex))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("$\(Int(budgetLimit - currentAmount)) left")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    // Mini Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 3)
                            
                            Rectangle()
                                .fill(Color(hex: category.colorHex))
                                .frame(width: geometry.size.width * progress, height: 3)
                                .mask(Capsule())
                        }
                    }
                    .frame(height: 3)
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color(hex: category.colorHex) : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var transactionNotesStep: some View {
        VStack(spacing: 16) {
            Text("Notes (Optional)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("e.g. Lunch with friends", text: $transactionNotes)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .submitLabel(.done)
        }
    }
}

#Preview {
    AddTransactionView()
}
