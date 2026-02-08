import SwiftUI

import CoreLocation

struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    var transactionToEdit: FirestoreModels.Transaction?
    var requestToAccept: FirestoreModels.SplitRequest?
    var onSave: ((Transaction) -> Void)?
    
    @StateObject private var budgetRepo = BudgetRepository()
    @StateObject private var transactionRepo = TransactionRepository()
    
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
        } else if let request = requestToAccept {
            amount = String(format: "%.2f", abs(request.amount))
            transactionNotes = request.note
            // We start at step 1 to confirm amount, but could jump to 2 if desired
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            if isReimbursement {
                readOnlyView
            } else {
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
        }
        .onAppear {
            populateData()
            
            if currencyManager.isTravelModeEnabled && currencyManager.mainCurrency != currencyManager.travelCurrency && transactionToEdit == nil {
                isUsingTravelCurrency = true
            }
            if !appState.currentUserId.isEmpty {
                budgetRepo.startListening(userId: appState.currentUserId)
                transactionRepo.startListening(userId: appState.currentUserId)
            }
            
            // Delay setting initial category to allow repo to load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let transaction = transactionToEdit, selectedCategory == nil {
                    // Try to find the category by name
                    if let categoryName = transaction.subtitle {
                        if let budget = budgetRepo.budgets.first(where: { $0.category == categoryName }) {
                            selectedCategory = budget
                        }
                    }
                }
            }
        }
        .presentationDetents(availableDetents, selection: $presentationDetent)
        .presentationDragIndicator(.visible)
        .onChange(of: presentationDetent) { _, newValue in
            // Sticky Logic: Once expanded to large, lock it there.
            if newValue == .large {
                availableDetents = [.large]
            }
        }
        .onDisappear {
            budgetRepo.stopListening()
            transactionRepo.stopListening()
        }
    }
    
    private var isReimbursement: Bool {
        guard let note = transactionToEdit?.note else { return false }
        return note.contains("Split Received:")
    }
    
    private var readOnlyView: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, AppSpacing.margin)
            .padding(.top, 16)
            
            // Icon
            if let t = transactionToEdit {
                Image(systemName: t.icon)
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: t.colorHex))
                    .padding()
                    .background(Color(hex: t.colorHex).opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Amount
            if let t = transactionToEdit {
                Text("+\(String(format: "%.2f", t.amount))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
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
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(AppRadius.medium)
            .padding(.horizontal, AppSpacing.margin)
            
            Spacer()
        }
    }
    
    private var stickyActionBar: some View {
        VStack {
            Button(action: {
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
    
    private func saveTransaction() {
        guard let category = selectedCategory else { return }
        
        // Ensure amount handles income vs expense correctly if needed
        let type = category.type ?? "expense"
        var newTransaction = Transaction(
            title: category.category,
            subtitle: category.category,
            amount: (type == "income" ? "" : "-") + amount,
            icon: category.icon,
            color: Color(hex: category.colorHex),
            date: selectedDate,
            notes: transactionNotes,
            type: type
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
            let rawAmount = Double(amount) ?? 0
            
            let mainAmount = currencyManager.convertToMain(amount: rawAmount, from: currencyManager.travelCurrency)
            
            // Re-assign amount in MAIN currency
            newTransaction.amount = String(format: "%.2f", (type == "income" ? 1 : -1) * mainAmount)
            
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
            // Handle both dot and comma
            let normalizedAmount = amount.replacingOccurrences(of: ",", with: ".")
            if let value = Double(normalizedAmount), value > 0 {
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
            
            if currencyManager.isTravelModeEnabled && currencyManager.mainCurrency != currencyManager.travelCurrency {
                Picker("Currency", selection: $isUsingTravelCurrency) {
                    Text(currencyManager.mainCurrency).tag(false)
                    Text(currencyManager.travelCurrency).tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.margin)
                
                if isUsingTravelCurrency {
                    Text("Converting to approx \(String(format: "%.2f", currencyManager.convertToMain(amount: Double(amount) ?? 0, from: currencyManager.travelCurrency))) \(currencyManager.mainCurrency)")
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
                        Button(action: {
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
                                        .frame(width: 32, height: 32)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        let category: FirestoreModels.CategoryBudget
        let budgetLimit: Double
        let currentAmount: Double
        @Binding var selectedCategory: FirestoreModels.CategoryBudget?
        
        var isSelected: Bool {
            selectedCategory?.category == category.category
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
                        Text(category.category)
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
            
            if transactionToEdit != nil {
                DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
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
