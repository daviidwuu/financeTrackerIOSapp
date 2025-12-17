import SwiftUI

struct AddRecurringTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    var recurringToEdit: FirestoreModels.RecurringTransaction?
    var onSave: ((RecurringTransaction) -> Void)?
    
    @StateObject private var budgetRepo = BudgetRepository()
    @StateObject private var transactionRepo = TransactionRepository()
    
    @State private var currentStep = 1
    @State private var amount: String = ""
    @State private var selectedCategory: FirestoreModels.Category?
    @State private var frequency: String = "Monthly"
    @State private var notes: String = ""
    @State private var direction: Edge = .trailing
    
    let frequencies = ["Weekly", "Bi-Weekly", "Monthly", "Yearly"]
    
    init(recurringToEdit: FirestoreModels.RecurringTransaction? = nil, onSave: ((RecurringTransaction) -> Void)? = nil) {
        self.recurringToEdit = recurringToEdit
        self.onSave = onSave
        
        if let transaction = recurringToEdit {
            _amount = State(initialValue: String(format: "%.2f", transaction.amount))
            _frequency = State(initialValue: transaction.frequency)
            _notes = State(initialValue: transaction.note ?? "")
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
                    
                    Text("Step \(currentStep) of 4")
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
                
                .padding()
                
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
                .frame(maxHeight: .infinity, alignment: .top) // Allow content to take available space
                
                Spacer()
                
                // Action Button
                Button(action: {
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
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isStepValid ? Color.white : Color.white.opacity(0.3))
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
                // Also listen to transactions for calculating remaining budget
                transactionRepo.startListening(userId: appState.currentUserId)
            }
        }
        .onDisappear {
            budgetRepo.stopListening()
            transactionRepo.stopListening()
        }
    }
    
    private func saveRecurring() {
        guard let amountValue = Double(amount), let category = selectedCategory else { return }
        
        let newRecurring = RecurringTransaction(
            name: category.name,
            amount: amountValue,
            icon: category.icon,
            color: Color(hex: category.colorHex),
            frequency: frequency,
            notes: notes
        )
        
        if let _ = recurringToEdit {
            onSave?(newRecurring)
        } else {
            onSave?(newRecurring)
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
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
        }
    }
    
    private var categoryStep: some View {
        VStack(spacing: 8) {
            Text("Select Category")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                    ForEach(budgetRepo.budgets) { budget in
                        let remaining = budget.remainingAmount(transactions: transactionRepo.transactions)
                        let progress = min(max(1.0 - (remaining / budget.totalAmount), 0.0), 1.0)
                        
                        Button(action: {
                            selectedCategory = FirestoreModels.Category(
                                id: nil,
                                name: budget.category,
                                icon: budget.icon,
                                colorHex: budget.colorHex,
                                type: budget.type ?? "expense",
                                userId: appState.currentUserId,
                                createdAt: Date()
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
                            .background(selectedCategory?.name == budget.category ? Color(hex: budget.colorHex).opacity(0.1) : Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedCategory?.name == budget.category ? Color(hex: budget.colorHex) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
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
        }
    }
}

#Preview {
    AddRecurringTransactionView()
        .environmentObject(AppState.shared)
}
