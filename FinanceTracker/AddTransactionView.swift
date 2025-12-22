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
                ModalHeader(
                    title: currentStep < 3 ? "Add Transaction" : "Details",
                    currentStep: currentStep,
                    totalSteps: 3,
                    onBack: currentStep > 1 ? {
                        direction = .leading
                        withAnimation { currentStep -= 1 }
                    } : nil,
                    onClose: { dismiss() }
                )
                
                // Content
                ZStack(alignment: .top) {
                    currentStepView
                }
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: direction),
                    removal: .move(edge: direction == .leading ? .trailing : .leading)
                ))
                .padding(.horizontal, AppSpacing.margin)
                .frame(maxHeight: .infinity, alignment: .top)
                
                Spacer()
                
                // Sticky Action Bar
                VStack {
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
                            .cornerRadius(AppRadius.button)
                    }
                    .disabled(!isStepValid)
                }
                .padding(AppSpacing.margin)
                .background(Material.bar)
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
            Spacer()
            
            Text("Amount")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("0.00", text: $amount)
                .font(AppTypography.heroInput)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private var detailsStep: some View {
        VStack(spacing: 8) {
            Text("Select Category")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: AppSpacing.element) {
                    ForEach(budgetRepo.budgets) { budget in
                        let remaining = budget.remainingAmount(transactions: transactionRepo.transactions)
                        let progress = min(max(1.0 - (remaining / budget.totalAmount), 0.0), 1.0)
                        
                        Button(action: {
                            selectedCategory = FirestoreModels.Category(
                                id: budget.id ?? UUID().uuidString,
                                name: budget.category,
                                icon: budget.icon,
                                colorHex: budget.colorHex,
                                type: budget.type ?? "expense",
                                userId: budget.userId,
                                createdAt: budget.createdAt
                            )
                            HapticManager.shared.light()
                        }) {
                            VStack(spacing: 0) {
                                HStack(spacing: 8) {
                                    Image(systemName: budget.icon)
                                        .font(.caption)
                                        .foregroundColor(Color(hex: budget.colorHex))
                                        .frame(width: 30, height: 30)
                                        .background(Color(hex: budget.colorHex).opacity(0.2))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(budget.category)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("$\(Int(remaining))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        if selectedCategory?.name == budget.category {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                                .padding(8)
                                
                                // Thin progress bar at bottom
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Color(hex: budget.colorHex).opacity(0.1)
                                        Color(hex: budget.colorHex)
                                            .frame(width: geometry.size.width * progress)
                                    }
                                }
                                .frame(height: 3)
                            }
                            }
                            .background(selectedCategory?.name == budget.category ? Color(hex: budget.colorHex).opacity(0.1) : Color(UIColor.secondarySystemBackground))
                            .cornerRadius(AppRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.small)
                                    .stroke(selectedCategory?.name == budget.category ? Color(hex: budget.colorHex) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .cornerRadius(AppRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.small)
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
