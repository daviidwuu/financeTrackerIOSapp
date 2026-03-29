import SwiftUI

import CoreLocation

struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var transactionToEdit: FirestoreModels.TransactionModel?
    var requestToAccept: FirestoreModels.SplitRequest?
    var initialCategoryName: String? // New property
    var onSave: ((TransactionFormData) -> Void)?
    
    // Repositories moved to AppState
    @EnvironmentObject var budgetRepo: BudgetRepository
    @EnvironmentObject var transactionRepo: TransactionRepository
    
    @State private var currentStep = 1
    @State private var amount: String = ""
    @State private var selectedCategory: FirestoreModels.CategoryBudget?
    @State private var selectedDate = Date()
    @State private var transactionNotes: String = ""
    @State private var direction: Edge = .trailing
    
    // Sticky Modal Logic
    @State private var presentationDetent: PresentationDetent = .medium
    @State private var availableDetents: Set<PresentationDetent> = [.medium, .large]
    
    // Travel Currency Logic
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var isUsingTravelCurrency = false
    @FocusState private var isAmountFocused: Bool
    
    private func populateData() {
        if let transaction = transactionToEdit {
            if abs(transaction.amount) != 0 {
                amount = String(format: "%.2f", abs(transaction.amount))
            }
            selectedDate = transaction.date
            transactionNotes = transaction.note ?? ""

            // Recover note from title for shortcut-created transactions
            // (shortcuts store user note in title with note: nil)
            if transactionNotes.isEmpty, let categoryId = transaction.categoryId {
                let categoryName = budgetRepo.getCategory(for: categoryId)?.category
                if let categoryName = categoryName, transaction.title != categoryName {
                    transactionNotes = transaction.title
                } else if categoryName == nil && !transaction.title.isEmpty {
                    transactionNotes = transaction.title
                }
            }

            // Restore travel currency state when editing a travel-currency transaction
            if let origAmount = transaction.originalAmount,
               let origCurrency = transaction.currencyCode {
                amount = String(format: "%.2f", abs(origAmount))
                isUsingTravelCurrency = true
                if currencyManager.travelCurrency != origCurrency {
                    currencyManager.travelCurrency = origCurrency
                }
                if let rate = transaction.exchangeRate {
                    currencyManager.exchangeRate = rate
                }
            }
        } else if let request = requestToAccept {
            amount = String(format: "%.2f", abs(request.amount))
            transactionNotes = request.note ?? ""
            // We start at step 1 to confirm amount, but could jump to 2 if desired
        }
    }
    
    var body: some View {
        Group {
            if isReimbursement {
                ZStack {
                    Color.backgroundPrimary
                        .ignoresSafeArea()
                    readOnlyView
                }
            } else {
                WizardLayout(
                    title: currentStep < 3 ? "Add Transaction" : "Details",
                    currentStep: currentStep,
                    totalSteps: 3,
                    onBack: currentStep > 1 ? {
                        direction = .leading
                        withAnimation { currentStep -= 1 }
                    } : nil,
                    onClose: { dismiss() },
                    direction: direction
                ) {
                    currentStepView
                } actionBar: {
                    Button(action: { HapticManager.shared.light(); 
                        // Sticky Logic: Enforce Large Detent on Interaction
                        availableDetents = [.large]
                        presentationDetent = .large
                        
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
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isStepValid)
                }
            }
        }
        .onAppear {
            populateData()
            
            if currencyManager.isTravelModeEnabled && currencyManager.mainCurrency != currencyManager.travelCurrency && transactionToEdit == nil {
                isUsingTravelCurrency = true
            }

            // Repos are handled in AppState, no need to manually start listening
        }
        // FIX #25: Replace hardcoded delay with reactive .task that re-fires when budgets change
        .task(id: budgetRepo.budgets.count) {
            guard selectedCategory == nil else { return }
            if let transaction = transactionToEdit {
                if let categoryId = transaction.categoryId {
                    if let budget = budgetRepo.budgets.first(where: { $0.id == categoryId }) {
                        selectedCategory = budget
                    }
                }
            } else if let initialName = initialCategoryName {
                if let budget = budgetRepo.budgets.first(where: { $0.category == initialName }) {
                    selectedCategory = budget
                }
            }
        }
        .presentationDetents(availableDetents, selection: $presentationDetent)
        .presentationBackground(Color.backgroundPrimary)
        .presentationDragIndicator(.visible)
        .onChange(of: presentationDetent) { _, newValue in
            // Sticky Logic: Once expanded to large, lock it there.
            if newValue == .large {
                availableDetents = [.large]
            }
        }
        .onDisappear {
            // Repos are handled in AppState
        }
    }
    
    private var isReimbursement: Bool {
        guard let note = transactionToEdit?.note else { return false }
        return note.contains("Split Received:")
    }
    
    private var readOnlyView: some View {
        VStack(spacing: AppSpacing.large) {
            // Header
            HStack {
                Spacer()
                Button(action: { HapticManager.shared.light();  dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, AppSpacing.margin)
            .padding(.top, 16)
            
            // Icon
            if let _ = transactionToEdit {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "#34C759"))
                    .padding()
                    .background(Color(hex: "#34C759").opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Amount
            if let t = transactionToEdit {
                Text("+\(String(format: "%.2f", t.amount))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(Color.functionalSuccess)
            }
            
            // Title
            if let t = transactionToEdit {
                Text(t.title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Info Box
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Automatic Transaction")
                    .font(.headline)
                
                Text("This is an automatic reimbursement for a split bill. To modify it, please update the split status on the original transaction.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
            .padding(.horizontal, AppSpacing.margin)
            
            Spacer()
        }
    }
    
    private func saveTransaction() {
        guard let category = selectedCategory else { return }
        
        // Ensure amount handles income vs expense correctly if needed
        let categoryType = category.type ?? "expense"
        
        // CRITICAL FIX: Preserve "settlement" type if editing a settlement
        // Also preserve "income" if it was originally income (though category usually handles this)
        var finalType = categoryType
        if let existing = transactionToEdit {
             if existing.type == "settlement" {
                 finalType = "settlement"
             } else if existing.type == "income" {
                 finalType = "income"
             }
        }
        
        var newTransaction = TransactionFormData(
            title: !transactionNotes.isEmpty ? transactionNotes : category.category,
            categoryId: category.id,
            amount: (finalType == "income" || finalType == "settlement" ? "" : "-") + amount,
            date: selectedDate,
            notes: transactionNotes,
            type: finalType
        )
        
        // --- Location Logic ---
        if let existing = transactionToEdit {
            // Preserve existing location
            newTransaction.latitude = existing.latitude
            newTransaction.longitude = existing.longitude
            newTransaction.locationName = existing.locationName
        } else {
            // New Transaction: Fetch Current Location if enabled
            if UserDefaults.standard.bool(forKey: "isLocationEnabled") == true { // Default to true if not set, handled by AppStorage logic elsewhere but safe to check true explicitly or change to register defaults
                // Actually AppStorage defaults are tricky in pure code without wrapper.
                // Let's rely on standard valid check.
                // Better approach: explicit check.
                
                // Note: @AppStorage in View is easiest, but inside func we use UserDefaults
                // or we add @AppStorage prop to View.
                // Let's use UserDefaults for simplicity in this func scope, assuming true default.
                let locationEnabled = UserDefaults.standard.object(forKey: "isLocationEnabled") as? Bool ?? true
                
                if locationEnabled {
                    let locStatus = LocationManager.shared.authorizationStatus
                    if locStatus == .authorizedWhenInUse || locStatus == .authorizedAlways {
                        if let location = LocationManager.shared.currentLocation {
                            newTransaction.latitude = location.coordinate.latitude
                            newTransaction.longitude = location.coordinate.longitude
                            // locationName can be resolved later or valid here
                        }
                    }
                }
            }
        }
        
        if isUsingTravelCurrency {
            let rawAmount = CurrencyInput.parseOrZero(amount)
            
            let mainAmount = currencyManager.convertToMain(amount: rawAmount, from: currencyManager.travelCurrency)
            
            // Re-assign amount in MAIN currency
            let signedAmount = (finalType == "income" ? 1.0 : -1.0) * mainAmount
            newTransaction.amount = String(format: "%.2f", signedAmount)
            
            // Store original details
            newTransaction.currencyCode = currencyManager.travelCurrency
            newTransaction.exchangeRate = currencyManager.exchangeRate
            newTransaction.originalAmount = rawAmount
        }
        
        if let _ = transactionToEdit {
            let updatedTransaction = newTransaction
            onSave?(updatedTransaction)
        } else {
            onSave?(newTransaction)
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
        VStack(spacing: AppSpacing.element) {
            Spacer()
            
            Text("Amount")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            
            if currencyManager.isTravelModeEnabled && currencyManager.mainCurrency != currencyManager.travelCurrency {
                Picker("Currency", selection: $isUsingTravelCurrency) {
                    Text(currencyManager.mainCurrency).tag(false)
                    Text(currencyManager.travelCurrency).tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.margin)
                
                if isUsingTravelCurrency {
                    Text("Converting to approx \(String(format: "%.2f", currencyManager.convertToMain(amount: CurrencyInput.parseOrZero(amount), from: currencyManager.travelCurrency))) \(currencyManager.mainCurrency)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            TextField("0.00", text: $amount)
            .font(AppTypography.heroInput)
            .multilineTextAlignment(.center)
            .keyboardType(.decimalPad)
            .foregroundColor(.primary)
            .focused($isAmountFocused)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAmountFocused = true
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.margin)
    }
    
    private var detailsStep: some View {
        VStack(spacing: 8) {
            Text("Select Category")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.horizontal, AppSpacing.margin)
            
            ScrollView {
                VStack(spacing: AppSpacing.element) {
                    // 1. Featured Income Card (if available)
                    if let incomeBudget = budgetRepo.budgets.first(where: { $0.category.lowercased() == "income" }) {
                        Button(action: { HapticManager.shared.light(); 
                            selectedCategory = incomeBudget
                            HapticManager.shared.light()
                        }) {
                            HStack {
                                Image(systemName: incomeBudget.icon)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
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
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: AppSpacing.element) {
                        // 2. Expense Categories
                        ForEach(budgetRepo.budgets.filter { $0.category.lowercased() != "income" }) { budget in
                            let remaining = budget.remainingAmount(transactions: transactionRepo.allTransactions)
                            let rawProgress: Double = budget.totalAmount > 0 ? (1.0 - (remaining / budget.totalAmount)) : 0.0
                            let progress = rawProgress.isFinite ? min(max(rawProgress, 0.0), 1.0) : 0.0
                            
                            Button(action: { HapticManager.shared.light(); 
                                selectedCategory = budget
                                HapticManager.shared.light()
                            }) {
                                VStack(spacing: 0) {
                                    HStack(spacing: 8) {
                                        Image(systemName: budget.icon) // Changed from "tag.fill"
                                        .font(.caption)
                                        .foregroundColor(Color(hex: budget.colorHex)) // Changed from .blue
                                        .frame(width: 32, height: 32)
                                        .background(Color(hex: budget.colorHex).opacity(0.2)) // Changed from .blue
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
                                                Text("\(CurrencyManager.shared.mainCurrency) \(Int(remaining))")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            if selectedCategory?.category == budget.category {
                                                Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(Color.functionalSuccess)
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
                                .background(selectedCategory?.category == budget.category ? Color(hex: budget.colorHex).opacity(0.1) : Color.cardBackground)
                                .cornerRadius(AppRadius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.small)
                                    .stroke(selectedCategory?.category == budget.category ? Color(hex: budget.colorHex) : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.compact)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    

    

    
    private var transactionNotesStep: some View {
        VStack(spacing: AppSpacing.element) {
            Text("Notes (Optional)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("e.g. Lunch with friends", text: $transactionNotes)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .submitLabel(.done)
            
            if transactionToEdit != nil {
                // FIX #24: Prevent selecting future dates
                DatePicker("Date", selection: $selectedDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .padding(.top)
            }
        }
        .padding(.horizontal, AppSpacing.margin)
    }
}

#Preview {
    AddTransactionView()
}
