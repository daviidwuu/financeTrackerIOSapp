import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct OnboardingView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    

    
    @State private var currentStep = 1
    @State private var direction: Edge = .trailing
    
    // Step Data
    @State private var nameInput = ""
    @State private var usernameInput = ""
    @State private var incomeInput = ""
    @State private var emailInput = ""
    @State private var passwordInput = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private func getFirstOfNextMonth() -> Date {
        let calendar = Calendar.current
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: Date()) else { return Date() }
        let components = calendar.dateComponents([.year, .month], from: nextMonth)
        return calendar.date(from: components) ?? Date()
    }
    
    // Categories
    @State private var onboardingCategories: [OnboardingCategory] = [
        OnboardingCategory(name: "Food & Drink", icon: "fork.knife", colorHex: "#FF9500"),
        OnboardingCategory(name: "Transport", icon: "car.fill", colorHex: "#007AFF"),
        OnboardingCategory(name: "Bills", icon: "doc.text.fill", colorHex: "#FF3B30"),
        OnboardingCategory(name: "Shopping", icon: "bag.fill", colorHex: "#AF52DE"),
        OnboardingCategory(name: "Entertainment", icon: "tv.fill", colorHex: "#5856D6")
    ]
    
    struct OnboardingCategory: Identifiable {
        let id = UUID()
        var name: String
        var icon: String
        var colorHex: String
        var isSelected: Bool = true
        var budgetAmount: Double? = nil
    }
    
    // Saving Goals
    @State private var onboardingSavingGoals: [OnboardingSavingGoal] = [
        OnboardingSavingGoal(name: "Emergency Fund", targetAmount: 1000, icon: "lifepreserver.fill", colorHex: "#FF3B30"),
        OnboardingSavingGoal(name: "Vacation", targetAmount: 2000, icon: "airplane", colorHex: "#34C759"),
        OnboardingSavingGoal(name: "New Car", targetAmount: 20000, icon: "car.fill", colorHex: "#007AFF")
    ]
    
    struct OnboardingSavingGoal: Identifiable {
        let id = UUID()
        var name: String
        var targetAmount: Double
        var currentAmount: Double = 0
        var targetDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        var icon: String
        var colorHex: String
        var isSelected: Bool = true
    }
    
    // Recurring Transactions
    @State private var onboardingRecurringTransactions: [FirestoreModels.RecurringTransaction] = []
    
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Bar
                HStack(spacing: 4) {
                    ForEach(1...12, id: \.self) { step in
                        Capsule()
                            .fill(step <= currentStep ? Color.white : Color.gray.opacity(0.2))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
                
                // Content
                ZStack(alignment: .top) {
                    Group {
                        switch currentStep {
                        case 1: IntroStep()
                        case 2: ProfileStep(name: $nameInput)
                        case 3: SocialFeaturesStep()
                        case 4: UsernameStep(username: $usernameInput)
                        case 5: IncomeStep(income: $incomeInput)
                        case 6: CategoriesStep(categories: $onboardingCategories)
                        case 7: RecurringTransactionsStep(transactions: $onboardingRecurringTransactions, categories: onboardingCategories)
                        case 8: SavingGoalsStep(goals: $onboardingSavingGoals)
                        case 9: BackTapStep()
                        case 10: TravelModeStep()
                        case 11: WidgetStep()
                        case 12: AccountStep(email: $emailInput, password: $passwordInput, errorMessage: $errorMessage)
                        default: EmptyView()
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                
                Spacer()
                
                // Navigation Buttons (Sticky at bottom)
                HStack(spacing: 16) {
                    if currentStep > 1 {
                        Button(action: prevStep) {
                            Image(systemName: "arrow.left")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(width: 50, height: 50)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(Circle())
                        }
                    }
                    
                    Button(action: nextStep) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(currentStep == 12 ? "Create Account" : "Continue")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isStepValid ? Color.primary : Color.gray.opacity(0.3))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .cornerRadius(AppRadius.button)
                    }
                    .animation(nil, value: isStepValid) // Remove button color change animation
                    .disabled(!isStepValid || isLoading)
                }
                .padding(24)
                // Add background to buttons to prevent content overlap
                .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.9)) 
            }
        }
        .navigationBarHidden(true)
        .onAppear { onAppearAction() }
    }
    
    // MARK: - Logic
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1: return true
        case 2: return !nameInput.isEmpty
        case 3: return true // Social Features intro
        case 4: return !usernameInput.isEmpty && usernameInput.count >= 3
        case 5: return Double(incomeInput) != nil || incomeInput.isEmpty
        case 6: return !onboardingCategories.filter { $0.isSelected }.isEmpty
        case 7: return true // Recurring Transactions (Optional)
        case 8: return true // Saving Goals
        case 9: return true // Back Tap
        case 10: return true // Travel Mode
        case 11: return true // Widget
        case 12: return !emailInput.isEmpty && !passwordInput.isEmpty && emailInput.contains("@") && passwordInput.count >= 6
        default: return false
        }
    }
    
    private func nextStep() {
        hideKeyboard()
        if currentStep < 12 {
            direction = .trailing
            HapticManager.shared.light() // Navigation haptic
            currentStep += 1
        } else {
            HapticManager.shared.success() // Completion haptic
            completeOnboarding()
        }
    }
    
    private func prevStep() {
        hideKeyboard()
        if currentStep > 1 {
            direction = .leading
            HapticManager.shared.light() // Navigation haptic
            currentStep -= 1
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func completeOnboarding() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Create Account
                let result = try await FirebaseManager.shared.signUp(email: emailInput, password: passwordInput, name: nameInput, username: usernameInput)
                let userId = result.uid
                
                // 2. Create Recurring Income Transaction
                let recurringIncome = FirestoreModels.RecurringTransaction(
                    id: UUID().uuidString,
                    name: "Salary",
                    amount: Double(incomeInput) ?? 0.0,
                    frequency: "Monthly",
                    startDate: getFirstOfNextMonth(),
                    icon: "dollarsign.circle.fill",
                    colorHex: "#34C759", // Green
                    note: "Auto-generated from onboarding",
                    type: "income",
                    userId: userId,
                    createdAt: Date()
                )
                let recurringRef = Firestore.firestore().collection("users").document(userId).collection("recurringTransactions").document(recurringIncome.id!)
                try recurringRef.setData(from: recurringIncome)

                // 2b. Create Additional Recurring Transactions
                for recurring in onboardingRecurringTransactions {
                    var newRecurring = recurring
                    newRecurring.userId = userId // Assign User ID
                    let ref = Firestore.firestore().collection("users").document(userId).collection("recurringTransactions").document(newRecurring.id ?? UUID().uuidString)
                    try ref.setData(from: newRecurring)
                }

                // 3. Create Categories in Firestore
                let db = Firestore.firestore()
                // Use all categories in the list
                let selectedCategories = onboardingCategories
                
                let batch = db.batch()
                
                for cat in selectedCategories {
                    // Create Budget/Category equivalent
                    // In this new model, every category is a Budget.
                    // If no limit is set, we can set a high number or 0.
                    // Let's set 0 if nil, implying no specific limit or tracking only.
                    
                    let newBudget = FirestoreModels.CategoryBudget(
                        id: UUID().uuidString,
                        category: cat.name,
                        totalAmount: cat.budgetAmount ?? 0.0, // Default to 0 if no limit set
                        icon: cat.icon,
                        colorHex: cat.colorHex,
                        frequency: "Monthly", // Default to Monthly
                        type: "expense",
                        userId: userId,
                        monthStartDate: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!,
                        createdAt: Date()
                    )
                    let budgetRef = db.collection("users").document(userId).collection("budgets").document(newBudget.id!)
                    try batch.setData(from: newBudget, forDocument: budgetRef)
                }
                
                // 4. Create Saving Goals in Firestore
                let selectedGoals = onboardingSavingGoals.filter { $0.isSelected }
                for goal in selectedGoals {
                    let newGoal = FirestoreModels.SavingGoal(
                        id: UUID().uuidString,
                        name: goal.name,
                        targetAmount: goal.targetAmount,
                        currentAmount: goal.currentAmount,
                        targetDate: goal.targetDate,
                        icon: goal.icon,
                        colorHex: goal.colorHex,
                        sortOrder: 0,
                        userId: userId,
                        createdAt: Date()
                    )
                    let goalRef = db.collection("users").document(userId).collection("savingGoals").document(newGoal.id!)
                    try batch.setData(from: newGoal, forDocument: goalRef)
                }

                try await batch.commit()
                
                // 5. create Default Income Category
                let incomeBudget = FirestoreModels.CategoryBudget(
                    id: UUID().uuidString,
                    category: "Income",
                    totalAmount: 0,
                    icon: "plus.circle.fill",
                    colorHex: "#34C759", // System Green
                    frequency: "Monthly",
                    type: "income",
                    userId: userId,
                    monthStartDate: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!,
                    createdAt: Date()
                )
                try db.collection("users").document(userId).collection("budgets").document(incomeBudget.id!).setData(from: incomeBudget)
                
                // 5. Update AppState
                await MainActor.run {
                    appState.userName = nameInput
                    appState.currentUserUsername = usernameInput
                    appState.userEmail = emailInput
                    appState.currentUserId = userId
                    appState.isUserLoggedIn = true
                    appState.hasCompletedOnboarding = true
                    UserDefaults.standard.set(Date(), forKey: "userSignupDate")
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Steps

struct IntroStep: View {
    @ViewBuilder
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            // Using a standard color directly to avoid closure type issues if Environment isn't cooperating in this specific context context
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(.yellow) 
                .padding()
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 160, height: 160)
                )
            
            VStack(spacing: 12) {
                Text("Welcome to spendi")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("Let's set up your profile and financial goals in just a few steps.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }
}

struct ProfileStep: View {
    @Binding var name: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("What should we call you?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            TextField("Your Name", text: $name)
                .font(AppTypography.heroInput)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.clear)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

struct UsernameStep: View {
    @Binding var username: String
    @State private var isChecking = false
    @State private var availabilityMessage = ""
    @State private var isAvailable = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Pick a Username")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            Text("Friends can use this to find you.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                TextField("username", text: $username)
                    .font(AppTypography.heroInput)
                    .multilineTextAlignment(.center)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color.clear)
                    .padding(.horizontal, 32)
                    .onChange(of: username) { _, newValue in
                        checkAvailability(newValue)
                    }
                
                if !username.isEmpty {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .font(.caption)
                        } else {
                            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isAvailable ? .green : .red)
                            Text(availabilityMessage)
                                .font(.caption)
                                .foregroundColor(isAvailable ? .green : .red)
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func checkAvailability(_ name: String) {
        guard name.count >= 3 else {
            isAvailable = false
            availabilityMessage = "Too short"
            return
        }
        
        isChecking = true
        // Simple debounce by delaying task
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if Task.isCancelled { return }
            
            do {
                let available = try await FirebaseManager.shared.checkUsernameAvailability(name)
                await MainActor.run {
                    isChecking = false
                    isAvailable = available
                    availabilityMessage = available ? "Available" : "Taken"
                }
            } catch {
                await MainActor.run {
                    isChecking = false
                    isAvailable = false
                    availabilityMessage = "Error checking"
                }
            }
        }
    }
}

struct IncomeStep: View {
    @Binding var income: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding(.bottom, 20)
            
            Text("What is your monthly income?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                TextField("0", text: $income)
                    .keyboardType(.numberPad)
                    .font(AppTypography.heroInput)
                    .multilineTextAlignment(.leading)
                    .fixedSize()
            }
            
            Text("This will be set as your recurring monthly salary.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

struct CategoriesStep: View {
    @Binding var categories: [OnboardingView.OnboardingCategory]
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var categoryToEdit: OnboardingView.OnboardingCategory?
    @State private var editSheetInitialStep = 1
    @State private var showSwipeGuide = false
    @State private var hasShownGuide = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Customize Categories")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            List {
                ForEach(categories) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: category.colorHex).opacity(0.2))
                            .foregroundColor(Color(hex: category.colorHex))
                            .clipShape(Circle())
                        
                        Text(category.name)
                            .font(.headline)
                        
                        Spacer()
                        
                        if let amount = category.budgetAmount {
                            Text("$\(Int(amount)) Limit")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                                .contentShape(Rectangle())
                                .highPriorityGesture(TapGesture().onEnded {
                                    editSheetInitialStep = 2
                                    categoryToEdit = category
                                })
                        } else {
                            Text("Set Budget")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                                .contentShape(Rectangle())
                                .highPriorityGesture(TapGesture().onEnded {
                                    editSheetInitialStep = 2
                                    categoryToEdit = category
                                })
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.bottom, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editSheetInitialStep = 1
                        categoryToEdit = category
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            HapticManager.shared.medium()
                            categoryToEdit = category
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            HapticManager.shared.heavy()
                            if let index = categories.firstIndex(where: { $0.id == category.id }) {
                                categories.remove(at: index)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            
            Button(action: {
                // Create a new empty category and open the sheet
                let newCat = OnboardingView.OnboardingCategory(name: "", icon: "tag.fill", colorHex: "#808080")
                categoryToEdit = newCat
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Category")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
            }

        }
            .overlay {
                if showSwipeGuide {
                    SwipeGuideView(onDismiss: {
                        showSwipeGuide = false
                        hasShownGuide = true
                    })
                }
            }
            .onAppear {
                if !hasShownGuide {
                    // Slight delay to allow view to appear fully
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSwipeGuide = true
                    }
                }
            }
            .sheet(item: $categoryToEdit) { category in
                EditCategorySheet(
                    category: category,
                    initialStep: editSheetInitialStep,
                    onSave: { updatedCategory in
                        if let index = categories.firstIndex(where: { $0.id == updatedCategory.id }) {
                            categories[index] = updatedCategory
                        } else {
                            // Append new category if ID not found (newly created)
                            // Note: ID for newCat is created on init, so it won't match any existing category unless we strictly check against the list content which holds value types.
                            // Actually, OnboardingCategory is a struct and id is let UUID().
                            // 'categoryToEdit' has a UUID. If that UUID is in 'categories', update. Else, append.
                            // However, since 'categories' is [OnboardingCategory], we need to check if an item with that ID exists.
                            // When we created 'newCat', it has a unique ID. It is NOT in 'categories' yet.
                            // So 'firstIndex' returns nil. We append. Correct.
                            categories.append(updatedCategory)
                        }
                        categoryToEdit = nil
                    },
                    onDelete: {
                        if let index = categories.firstIndex(where: { $0.id == category.id }) {
                            categories.remove(at: index)
                        }
                        categoryToEdit = nil
                    }
                )
            }
    }
}

struct EditCategorySheet: View {
    @State var category: OnboardingView.OnboardingCategory
    var initialStep: Int = 1
    var onSave: (OnboardingView.OnboardingCategory) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Wizard State
    @State private var currentStep = 1
    @State private var direction: Edge = .trailing
    @State private var presentationDetent: PresentationDetent = .medium
    
    // Form Data
    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var selectedIcon: String = ""
    @State private var selectedColorHex: String = ""
    
    // Constants
    // Constants
    let icons = AppConstants.allIcons
    let colors = AppConstants.allColors
    
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
                            currentStep -= 1
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
                    
                    // Delete Button (Only on Step 1)
                    if currentStep == 1 {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.red)
                                .frame(width: 44, height: 44)
                        }
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
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
                    if currentStep < 4 {
                        HapticManager.shared.light()
                        direction = .trailing
                        currentStep += 1
                    } else {
                        HapticManager.shared.success()
                        saveChanges()
                    }
                }) {
                    Text(currentStep < 4 ? "Next" : "Save Changes")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50) // Standardize height
                        .background(isStepValid ? Color.primary : Color.primary.opacity(0.3))
                        .cornerRadius(AppRadius.button) // Use standard radius
                        .contentShape(Rectangle()) // Explicitly define hit area
                }
                .disabled(!isStepValid)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium, .large], selection: $presentationDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            // Initialize state
            currentStep = initialStep
            name = category.name
            selectedIcon = category.icon
            selectedColorHex = category.colorHex
            if let amount = category.budgetAmount, amount != 0 {
                amountString = String(format: "%.0f", amount)
            }
        }
    }
    
    private func saveChanges() {
        var updatedCategory = category
        updatedCategory.name = name
        updatedCategory.icon = selectedIcon
        updatedCategory.colorHex = selectedColorHex
        
        if let amount = Double(amountString), amount > 0 {
            updatedCategory.budgetAmount = amount
        } else {
            updatedCategory.budgetAmount = nil
        }
        
        onSave(updatedCategory)
        dismiss()
    }
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1: return !name.isEmpty
        case 2: return true // Budget is optional
        case 3: return !selectedIcon.isEmpty
        case 4: return !selectedColorHex.isEmpty
        default: return false
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 1: nameStep
        case 2: limitStep
        case 3: iconStep
        case 4: colorStep
        default: EmptyView()
        }
    }
    
    // MARK: - Steps
    
    private var nameStep: some View {
        VStack(spacing: 16) {
            Text("Category Name")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("e.g. Rent", text: $name)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding()
                .background(Color.black)
                .cornerRadius(12)
        }
    }
    
    private var limitStep: some View {
        VStack(spacing: 16) {
            Text("Budget Limit")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("Optional", text: $amountString)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
            
            Text("Leave empty for no limit")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var iconStep: some View {
        VStack(spacing: 24) {
            Text("Select Icon")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 20) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: { 
                            selectedIcon = icon 
                            HapticManager.shared.selection()
                        }) {
                            Circle()
                                .fill(selectedIcon == icon ? Color.primary : Color.secondary.opacity(0.1))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? (colorScheme == .dark ? .black : .white) : .primary)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20) // Add padding for bottom spacing
            }
        }
    }
    
    private var colorStep: some View {
        VStack(spacing: 24) {
            Text("Select Color")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 20) {
                    ForEach(colors, id: \.self) { color in
                        let hex = color.toHex() ?? "#000000"
                        Button(action: { 
                            selectedColorHex = hex
                            HapticManager.shared.selection()
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorHex == hex ? 3 : 0)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .opacity(selectedColorHex == hex ? 1 : 0)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
}



struct AccountStep: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Create your account")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                CustomSecureField(icon: "lock.fill", placeholder: "Password (min 6 chars)", text: $password)
            }
            .padding(.horizontal, 32)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

struct SavingGoalsStep: View {
    @Binding var goals: [OnboardingView.OnboardingSavingGoal]
    @State private var goalToEdit: OnboardingView.OnboardingSavingGoal?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Set Saving Goals")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            List {
                ForEach(goals) { goal in
                    HStack {
                        Image(systemName: goal.icon)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: goal.colorHex).opacity(0.2))
                            .foregroundColor(Color(hex: goal.colorHex))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(goal.name)
                                .font(.headline)
                            Text("Target: $\(Int(goal.targetAmount))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Checkbox for selection
                        Image(systemName: goal.isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(goal.isSelected ? Color.blue : Color.gray)
                            .onTapGesture {
                                if let index = goals.firstIndex(where: { $0.id == goal.id }) {
                                    HapticManager.shared.selection() // Selection haptic
                                    goals[index].isSelected.toggle()
                                }
                            }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.bottom, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        goalToEdit = goal
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            HapticManager.shared.heavy()
                            if let index = goals.firstIndex(where: { $0.id == goal.id }) {
                                goals.remove(at: index)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            
            Button(action: {
                // Create a new goal and open the sheet
                let newGoal = OnboardingView.OnboardingSavingGoal(name: "", targetAmount: 500, icon: "star.fill", colorHex: "#FFD60A")
                goalToEdit = newGoal
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Saving Goal")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .sheet(item: $goalToEdit) { goal in
            EditSavingGoalSheet(
                goal: goal,
                onSave: { updatedGoal in
                    if let index = goals.firstIndex(where: { $0.id == updatedGoal.id }) {
                        goals[index] = updatedGoal
                        goals[index].isSelected = true
                    } else {
                        var newGoal = updatedGoal
                        newGoal.isSelected = true
                        goals.append(newGoal)
                    }
                    goalToEdit = nil
                },
                onDelete: {
                    if let index = goals.firstIndex(where: { $0.id == goal.id }) {
                        goals.remove(at: index)
                    }
                    goalToEdit = nil
                }
            )
            .presentationDetents([.fraction(0.85)])
            .presentationDragIndicator(.visible)
        }
    }
}

struct EditSavingGoalSheet: View {
    @State var goal: OnboardingView.OnboardingSavingGoal
    var onSave: (OnboardingView.OnboardingSavingGoal) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Wizard State
    @State private var currentStep = 1
    @State private var direction: Edge = .trailing
    
    // Form Data
    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var selectedIcon: String = ""
    @State private var selectedColorHex: String = ""
    @State private var targetDate: Date = Date()
        
    // Constants
    let icons = AppConstants.allIcons
    let colors = AppConstants.allColors
    
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
                            currentStep -= 1
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
                    
                    Text("Step \(currentStep) of 5")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Delete Button (Only on Step 1)
                    if currentStep == 1 {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.red)
                                .frame(width: 44, height: 44)
                        }
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
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
                    if currentStep < 5 {
                        HapticManager.shared.light()
                        direction = .trailing
                        currentStep += 1
                    } else {
                        HapticManager.shared.success()
                        saveChanges()
                    }
                }) {
                    Text(currentStep < 5 ? "Next" : "Save Changes")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(height: 50)
                        .background(isStepValid ? Color.primary : Color.primary.opacity(0.3))
                        .cornerRadius(AppRadius.button)
                }
                .disabled(!isStepValid)
                .padding()
            }
        }
        .onAppear {
            // Initialize state
            name = goal.name
            selectedIcon = goal.icon
            selectedColorHex = goal.colorHex
            amountString = String(format: "%.0f", goal.targetAmount)
            targetDate = goal.targetDate
        }
    }
    
    private func saveChanges() {
        var updatedGoal = goal
        updatedGoal.name = name
        updatedGoal.icon = selectedIcon
        updatedGoal.colorHex = selectedColorHex
        updatedGoal.targetDate = targetDate
        if let amount = Double(amountString) {
            updatedGoal.targetAmount = amount
        }
        
        onSave(updatedGoal)
        dismiss()
    }
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1: return !name.isEmpty
        case 2: return Double(amountString) != nil
        case 3: return !selectedIcon.isEmpty
        case 4: return !selectedColorHex.isEmpty
        case 5: return true
        default: return false
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 1: nameStep
        case 2: amountStep
        case 3: iconStep
        case 4: colorStep
        case 5: dateStep
        default: EmptyView()
        }
    }
    
    // MARK: - Steps
    
    private var nameStep: some View {
        VStack(spacing: 16) {
            Text("Goal Name")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("e.g. New Car", text: $name)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding()
                .background(Color.black)
                .cornerRadius(12)
        }
    }
    
    private var amountStep: some View {
        VStack(spacing: 16) {
            Text("Target Amount")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("Amount", text: $amountString)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
            
            Text("How much do you want to save?")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var iconStep: some View {
        VStack(spacing: 24) {
            Text("Select Icon")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 20) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: { 
                            selectedIcon = icon
                            HapticManager.shared.selection()
                        }) {
                            Circle()
                                .fill(selectedIcon == icon ? Color.primary : Color.secondary.opacity(0.1))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? (colorScheme == .dark ? .black : .white) : .primary)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
    
    private var colorStep: some View {
        VStack(spacing: 24) {
            Text("Select Color")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 20) {
                    ForEach(colors, id: \.self) { color in
                        let hex = color.toHex() ?? "#000000"
                        Button(action: { 
                            selectedColorHex = hex
                            HapticManager.shared.selection()
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorHex == hex ? 3 : 0)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .opacity(selectedColorHex == hex ? 1 : 0)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
    
    private var dateStep: some View {
        VStack(spacing: 16) {
            Text("When do you need it?")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            DatePicker("", selection: $targetDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
                .tint(Color(hex: selectedColorHex))
        }
    }
}

struct BackTapStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(.bottom, 20)
            
            Text("Quick Log with Back Tap")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                Text("Did you know you can log expenses without opening the app?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Text("1.")
                            .bold()
                        Text("Go to **Settings > Accessibility > Touch > Back Tap**")
                    }
                    HStack(alignment: .top) {
                        Text("2.")
                            .bold()
                        Text("Choose **Double Tap** or **Triple Tap**")
                    }
                    HStack(alignment: .top) {
                        Text("3.")
                            .bold()
                        Text("Scroll down to Shortcuts and select **Log Expense**")
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
                
                Text("Now just tap the back of your phone to log a transaction instantly!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

struct WidgetStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 80))
                .foregroundColor(.purple)
                .padding(.bottom, 20)
            
            Text("Track on Home Screen")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                Text("Keep an eye on your finances with our widgets.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.secondary)
                        Text("Long press on your Home Screen to add widgets")
                    }
                    HStack(alignment: .top) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.secondary)
                        Text("See your daily spending at a glance")
                    }
                    HStack(alignment: .top) {
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                            .foregroundColor(.secondary)
                        Text("View recent transactions quickly")
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}
struct SocialFeaturesStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon Stack
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 160, height: 160)
                
                HStack(spacing: -20) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue.opacity(0.6))
                    Image(systemName: "person.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.blue)
                        .zIndex(1)
                    Image(systemName: "person.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue.opacity(0.6))
                }
            }
            .padding(.bottom, 20)
            
            VStack(spacing: 12) {
                Text("Split Bills with Friends")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("Easily track shared expenses and settle debts.\nCreate your unique username next so friends can find you!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

struct TravelModeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 160, height: 160)
                
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.purple)
            }
            .padding(.bottom, 20)
            
            VStack(spacing: 12) {
                Text("Travel Mode")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("Going abroad? Turn on Travel Mode to automatically handle foreign currencies and exchange rates based on your location.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}
#Preview {
    OnboardingView()
}

extension OnboardingView {
    func onAppearAction() {
        Task {
            try? await FirebaseManager.shared.signInAnonymously()
        }
    }
}

struct RecurringTransactionsStep: View {
    @Binding var transactions: [FirestoreModels.RecurringTransaction]
    var categories: [OnboardingView.OnboardingCategory]
    @State private var showAddSheet = false
    @State private var transactionToEdit: FirestoreModels.RecurringTransaction?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Recurring Expenses")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            Text("Add your subscriptions, bills, or rent.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if transactions.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No recurring transactions added yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal)
            } else {
                List {
                    ForEach(transactions) { transaction in
                        RecurringTransactionCard(
                            transaction: transaction,
                            onDelete: {
                                if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                                    transactions.remove(at: index)
                                }
                            },
                            onEdit: {
                                transactionToEdit = transaction
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
            
            Button(action: {
                showAddSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Recurring")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            OnboardingAddRecurringSheet(
                categories: categories,
                onSave: { transaction in
                    transactions.append(transaction)
                }
            )
        }
        .sheet(item: $transactionToEdit) { transaction in
            OnboardingAddRecurringSheet(
                transactionToEdit: transaction,
                categories: categories,
                onSave: { updatedTransaction in
                    if let index = transactions.firstIndex(where: { $0.id == updatedTransaction.id }) {
                        transactions[index] = updatedTransaction
                    }
                }
            )
        }
    }
}

struct OnboardingAddRecurringSheet: View {
    var transactionToEdit: FirestoreModels.RecurringTransaction?
    var categories: [OnboardingView.OnboardingCategory]
    var onSave: (FirestoreModels.RecurringTransaction) -> Void
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var currentStep = 1
    @State private var amount: String = ""
    @State private var selectedCategory: OnboardingView.OnboardingCategory?
    @State private var frequency: String = "Monthly"
    @State private var startDate = Date()
    @State private var notes: String = ""
    @State private var direction: Edge = .trailing
    @State private var presentationDetent: PresentationDetent = .medium
    
    let frequencies = ["Weekly", "Bi-Weekly", "Monthly", "Yearly"]
    
    init(transactionToEdit: FirestoreModels.RecurringTransaction? = nil, categories: [OnboardingView.OnboardingCategory], onSave: @escaping (FirestoreModels.RecurringTransaction) -> Void) {
        self.transactionToEdit = transactionToEdit
        self.categories = categories
        self.onSave = onSave
        
        if let transaction = transactionToEdit {
            _amount = State(initialValue: String(format: "%.2f", transaction.amount))
            _frequency = State(initialValue: transaction.frequency)
            _startDate = State(initialValue: transaction.startDate)
            _notes = State(initialValue: transaction.note ?? "")
            // Category matching might be approximate since we only have names/icons in local state
            // Logic to find category by name or icon ideally
        }
    }
    
    // We try to match pre-selected category in onAppear
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        if currentStep > 1 {
                            HapticManager.shared.light()
                            direction = .leading
                            currentStep -= 1
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: currentStep > 1 ? "chevron.left" : "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text(currentStep < 4 ? "Add Recurring" : "Confirm")
                        .font(.headline)
                    Spacer()
                    Color.clear.frame(width: 22)
                }
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
                .frame(maxHeight: .infinity, alignment: .top)
                
                Spacer()
                
                // Button
                Button(action: {
                    if currentStep < 4 {
                        HapticManager.shared.light()
                        direction = .trailing
                        currentStep += 1
                    } else {
                        HapticManager.shared.success()
                        save()
                    }
                }) {
                    Text(currentStep < 4 ? "Next" : (transactionToEdit != nil ? "Update" : "Save"))
                        .font(.headline)
                        .bold()
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isStepValid ? Color.white : Color.white.opacity(0.3))
                        .cornerRadius(AppRadius.button)
                }
                .disabled(!isStepValid)
                .padding()
            }
        }
        .presentationDetents([.medium, .large], selection: $presentationDetent)
        .onAppear {
            if let transaction = transactionToEdit {
                // Try to find matching category by name/icon/color
                // This is a best-effort match for the UI selection state
                selectedCategory = categories.first(where: { $0.name == transaction.name })
                                  ?? categories.first(where: { $0.icon == transaction.icon })
            }
        }
    }
    
    private func save() {
        guard let amountValue = Double(amount), let category = selectedCategory else { return }
        
        let newTransaction = FirestoreModels.RecurringTransaction(
            id: transactionToEdit?.id ?? UUID().uuidString,
            name: category.name,
            amount: amountValue,
            frequency: frequency,
            startDate: startDate,
            icon: category.icon,
            colorHex: category.colorHex,
            note: notes,
            type: "expense", // Assuming Expense for now as Income is handled separately
            userId: "", // Will be set on save
            createdAt: Date()
        )
        onSave(newTransaction)
        dismiss()
    }
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1: return Double(amount) != nil
        case 2: return selectedCategory != nil
        case 3: return true
        case 4: return true
        default: return false
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        if currentStep == 1 { amountStep }
        else if currentStep == 2 { categoryStep }
        else if currentStep == 3 { frequencyStep }
        else { notesStep }
    }
    
    private var amountStep: some View {
        VStack(spacing: 16) {
            Text("Amount")
                .font(.title2).foregroundColor(.secondary)
            TextField("0.00", text: $amount)
                .font(AppTypography.heroInput)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
        }
        .padding(.horizontal)
    }
    
    private var categoryStep: some View {
        VStack(spacing: 8) {
            Text("Select Category")
                .font(.headline).foregroundColor(.secondary)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                    ForEach(categories) { category in
                        Button(action: {
                            selectedCategory = category
                            HapticManager.shared.light()
                        }) {
                            VStack {
                                HStack {
                                    Image(systemName: category.icon)
                                        .frame(width: 30, height: 30)
                                        .background(Color(hex: category.colorHex).opacity(0.2))
                                        .foregroundColor(Color(hex: category.colorHex))
                                        .clipShape(Circle())
                                    Text(category.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                    if selectedCategory?.id == category.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedCategory?.id == category.id ? Color(hex: category.colorHex) : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private var frequencyStep: some View {
        VStack(spacing: 16) {
            Text("Frequency")
                .font(.title2).foregroundColor(.secondary)
            Picker("Frequency", selection: $frequency) {
                ForEach(frequencies, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.wheel)
        }
    }
    
    private var notesStep: some View {
        VStack(spacing: 16) {
            Text("Notes (Optional)")
                .font(.title2).foregroundColor(.secondary)
            TextField("e.g. Monthly Rent", text: $notes)
                .font(.title)
                .multilineTextAlignment(.center)
            
            DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
        }
        .padding()
    }
}

