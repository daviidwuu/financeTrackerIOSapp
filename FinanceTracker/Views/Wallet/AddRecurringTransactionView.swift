import SwiftUI

struct AddRecurringTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    var recurringToEdit: FirestoreModels.RecurringTransaction?
    var onSave: ((RecurringTransactionFormData) -> Void)?
    
    // Repositories moved to AppState
    var budgetRepo: BudgetRepository { appState.budgetRepo }
    var transactionRepo: TransactionRepository { appState.transactionRepo }
    
    @State private var currentStep = 1
    @State private var amount: String = ""
    @State private var selectedCategory: FirestoreModels.CategoryBudget?
    @State private var frequency: String = "Monthly"
    @State private var startDate = Date()
    @State private var notes: String = ""
    @State private var direction: Edge = .trailing
    
    // Sticky Modal Logic
    @State private var presentationDetent: PresentationDetent = .medium
    
    let frequencies = ["Weekly", "Bi-Weekly", "Monthly", "Yearly"]
    
    private func populateData() {
        if let transaction = recurringToEdit {
            if transaction.amount != 0 {
                amount = String(format: "%.2f", transaction.amount)
            }
            frequency = transaction.frequency
            startDate = transaction.startDate
            notes = transaction.note ?? ""
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
                    title: currentStep < 4 ? "Add Recurring" : "Confirm",
                    currentStep: currentStep,
                    totalSteps: 4,
                    onBack: currentStep > 1 ? {
                        direction = .leading
                        withAnimation { currentStep -= 1 }
                    } : nil,
                    onClose: { dismiss() }
                )
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, 16)
                
                // Content
                ZStack(alignment: .top) {
                    currentStepView
                }
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: direction),
                    removal: .move(edge: direction == .leading ? .trailing : .leading)
                ))
                .frame(maxHeight: .infinity, alignment: .top)
                
                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                stickyActionBar
            }
        }
        .presentationDetents([.medium, .large], selection: $presentationDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            populateData()
            
            // Repos are handled in AppState
            // if !appState.currentUserId.isEmpty {
            //    budgetRepo.startListening(userId: appState.currentUserId)
            //    transactionRepo.startListening(userId: appState.currentUserId)
            // }
            
            // Delay setting initial category to allow repo to load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let recurring = recurringToEdit, selectedCategory == nil {
                    // Try to find the category by name
                    if let budget = budgetRepo.budgets.first(where: { $0.category == recurring.name }) {
                        selectedCategory = budget
                    }
                }
            }
        }
        .onDisappear {
            // Repos are handled in AppState
        }
    }
    
    private var stickyActionBar: some View {
        VStack {
            Button(action: {
                // Sticky Logic: Enforce Large Detent
                presentationDetent = .large
                
                if currentStep < 4 {
                    HapticManager.shared.light()
                    direction = .trailing
                    withAnimation { currentStep += 1 }
                } else {
                    HapticManager.shared.success()
                    saveRecurring()
                }
            }) {
                Text(currentStep < 4 ? "Next" : (recurringToEdit != nil ? "Update Recurring" : "Save Recurring"))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isStepValid ? (colorScheme == .dark ? .black : .white) : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isStepValid ? Color.primary : Color(UIColor.systemGray5))
                    .cornerRadius(AppRadius.button)
            }
            .disabled(!isStepValid)
            .animation(.easeInOut, value: isStepValid) // Smooth color transition
        }
        .padding(.horizontal, AppSpacing.margin)
        .padding(.top, AppSpacing.compact)
        .padding(.bottom, 8) // Reduced bottom padding
        .background(Color.backgroundPrimary)
        .animation(.easeInOut, value: currentStep) // Smooth transitions
    }
    
    private func saveRecurring() {
        guard let amountValue = CurrencyInput.parse(amount), let category = selectedCategory else { return }
        
        let newRecurring = RecurringTransactionFormData(
            name: category.category,
            amount: amountValue,
            icon: category.icon,
            color: Color(hex: category.colorHex),
            frequency: frequency,
            startDate: startDate,
            notes: notes,
            type: category.type ?? "expense"
        )
        
        if let _ = recurringToEdit {
            onSave?(newRecurring)
        } else {
            onSave?(newRecurring)
            // Gamification
            GamificationManager.shared.completeMission(id: "subscription_tracker")
        }
        dismiss()
    }
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1:
            return CurrencyInput.isValid(amount)
        case 2:
            return selectedCategory != nil
        case 3:
            return true
        case 4:
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
            categoryStep
        } else if currentStep == 3 {
            frequencyStep
        } else {
            notesStep
        }
    }
    
    private var amountStep: some View {
        VStack(spacing: 16) {
            Text("Amount")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("0.00", text: $amount)
                .font(AppTypography.heroInput)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, AppSpacing.margin)
    }
    
    private var categoryStep: some View {
        VStack(spacing: 8) {
            Text("Select Category")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ScrollView {
                VStack(spacing: 12) {
                    // 1. Featured Income Card (if available)
                    if let incomeBudget = budgetRepo.budgets.first(where: { $0.category.lowercased() == "income" }) {
                        Button(action: {
                            selectedCategory = incomeBudget
                            HapticManager.shared.light()
                        }) {
                            HStack {
                                Image(systemName: incomeBudget.icon)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                                
                                Text(incomeBudget.category)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if selectedCategory?.category == incomeBudget.category {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: incomeBudget.colorHex)) // Green background
                            .cornerRadius(AppRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(Color.white.opacity(0.5), lineWidth: selectedCategory?.category == incomeBudget.category ? 4 : 0)
                            )
                        }
                        .padding(.horizontal, AppSpacing.compact) // Match grid padding
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                        ForEach(budgetRepo.budgets.filter { $0.category.lowercased() != "income" }) { budget in
                            let remaining = budget.remainingAmount(transactions: transactionRepo.transactions)
                            let progress = min(max(1.0 - (remaining / budget.totalAmount), 0.0), 1.0)
                            
                            Button(action: {
                                selectedCategory = budget
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
                                            if budget.type != "income" {
                                                Text("$\(Int(remaining))")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            if selectedCategory?.category == budget.category {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .padding(AppSpacing.compact)
                                    
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
                                .background(selectedCategory?.category == budget.category ? Color(hex: budget.colorHex).opacity(0.1) : Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.small)
                                        .stroke(selectedCategory?.category == budget.category ? Color(hex: budget.colorHex) : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.compact)
                }
            }
        }
    }
    
    private var frequencyStep: some View {
        VStack(spacing: 16) {
            Text("Frequency")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Picker("Frequency", selection: $frequency) {
                ForEach(frequencies, id: \.self) { freq in
                    Text(freq).tag(freq)
                }
            }
            .pickerStyle(.wheel)
        }
        .padding(.horizontal, AppSpacing.margin)
    }
    
    private var notesStep: some View {
        VStack(spacing: 16) {
            Text("Notes (Optional)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("e.g. Monthly Rent Payment", text: $notes)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .submitLabel(.done)
            
            DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .padding(.top)
        }
        .padding(.horizontal, AppSpacing.margin)
    }
}

#Preview {
    AddRecurringTransactionView()
        .environmentObject(AppState.shared)
}
