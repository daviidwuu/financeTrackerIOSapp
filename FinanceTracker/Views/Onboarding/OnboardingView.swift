import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

struct OnboardingView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    

    
    enum Field: Hashable {
        case name
        case username
        case income
        case email
        case password
    }
    
    @FocusState private var focusedField: Field?
    
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
        var isSelected: Bool = false
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
                    ForEach(1...6, id: \.self) { step in
                        Capsule()
                            .fill(step <= currentStep ? Color.primary : Color.gray.opacity(0.2))
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
                        case 2: ProfileStep(name: $nameInput, focusedField: $focusedField, onNext: nextStep)
                        case 3: UsernameStep(username: $usernameInput, focusedField: $focusedField, onNext: nextStep)
                        case 4: IncomeStep(income: $incomeInput, focusedField: $focusedField)
                        case 5: CategoriesStep(categories: $onboardingCategories)
                        case 6: AccountStep(email: $emailInput, password: $passwordInput, errorMessage: $errorMessage, focusedField: $focusedField, onSubmit: nextStep)
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
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.backgroundPrimary))
                            } else {
                                Text(currentStep == 6 ? "Create Account" : "Continue")
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isStepValid || isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Login Bypass Link
                NavigationLink(destination: LoginView()) {
                    Text("Already have an account? Log In")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.brandPrimary)
                        .padding(.bottom, 24)
                }
                
                // Add background to buttons to prevent content overlap
                .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.9)) 
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -50 && isStepValid {
                        nextStep()
                    } else if value.translation.width > 50 && currentStep > 1 {
                        prevStep()
                    }
                }
        )
        .navigationBarHidden(true)
        .onAppear { onAppearAction() }
    }
    
    // MARK: - Logic
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1: return true
        case 2: return !nameInput.isEmpty
        case 3: return !usernameInput.isEmpty && usernameInput.count >= 3
        case 4: return Double(incomeInput) != nil || incomeInput.isEmpty
        case 5: return !onboardingCategories.filter { $0.isSelected }.isEmpty
        case 6: return !emailInput.isEmpty && !passwordInput.isEmpty && emailInput.contains("@") && passwordInput.count >= 6
        default: return false
        }
    }
    
    private func nextStep() {
        hideKeyboard()
        if currentStep < 6 {
            direction = .trailing
            HapticManager.shared.light() // Navigation haptic
            currentStep += 1
            updateFocus()
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
            updateFocus()
        }
    }
    
    private func updateFocus() {
        // Slight delay to allow transition before focusing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch currentStep {
            case 2: focusedField = .name
            case 3: focusedField = .username
            case 4: focusedField = .income
            case 6: focusedField = .email
            default: focusedField = nil
            }
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
                    name: "Income",
                    amount: Double(incomeInput) ?? 0.0,
                    frequency: "Monthly",
                    startDate: getFirstOfNextMonth(),
                    icon: "dollarsign.circle.fill",
                    colorHex: "#34C759", // Green
                    note: "Salary",
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
                .foregroundColor(AppColors.brandPrimary) 
                .padding()
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 160, height: 160)
                )
            
            VStack(spacing: 12) {
                Text("Welcome to wym")
                    .font(AppTypography.heroRounded(size: 28))
                    .multilineTextAlignment(.center)
                
                Text("Let's set up your profile and financial goals in just a few steps.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.section)
            }
            Spacer()
        }
    }
}

struct ProfileStep: View {
    @Binding var name: String
    var focusedField: FocusState<OnboardingView.Field?>.Binding
    var onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("What should we call you?")
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
            
            TextField("Your Name", text: $name)
                .focused(focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit {
                    if !name.isEmpty {
                        onNext()
                    }
                }
                .font(AppTypography.heroInput)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.clear)
                .padding(.horizontal, AppSpacing.section)
            
            Spacer()
        }
    }
}

struct UsernameStep: View {
    @Binding var username: String
    var focusedField: FocusState<OnboardingView.Field?>.Binding
    var onNext: () -> Void
    @State private var isChecking = false
    @State private var availabilityMessage = ""
    @State private var isAvailable = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Pick a Username")
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
            
            Text("Friends can use this to find you.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                TextField("username", text: $username)
                    .focused(focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit {
                        if !username.isEmpty && username.count >= 3 && isAvailable {
                            onNext()
                        }
                    }
                    .font(AppTypography.heroInput)
                    .multilineTextAlignment(.center)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color.clear)
                    .padding(.horizontal, AppSpacing.section)
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
                                .foregroundColor(isAvailable ? AppColors.functionalIncome : AppColors.functionalExpense)
                            Text(availabilityMessage)
                                .font(.caption)
                                .foregroundColor(isAvailable ? AppColors.functionalIncome : AppColors.functionalExpense)
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
    var focusedField: FocusState<OnboardingView.Field?>.Binding
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppColors.functionalIncome.opacity(0.1))
                    .frame(width: 160, height: 160)
                
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.functionalIncome)
            }
            .padding(.bottom, 20)
            
            Text("What is your monthly income?")
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(AppTypography.heroRounded(size: 40))
                    .foregroundColor(.secondary)
                
                TextField("0", text: $income)
                    .focused(focusedField, equals: .income)
                    .keyboardType(.numberPad)
                    .font(AppTypography.heroInput)
                    .multilineTextAlignment(.leading)
                    .fixedSize()
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            if focusedField.wrappedValue == .income {
                                Spacer()
                                Button("Done") {
                                    focusedField.wrappedValue = nil
                                }
                            }
                        }
                    }
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
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            if categories.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tray.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No categories yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            } else {
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
                        .cornerRadius(AppRadius.medium)
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
            }
            
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
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.clear)
                .cornerRadius(AppRadius.small)
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
                    // Sticky Logic: Enforce Large Detent
                    presentationDetent = .large
                    
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
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isStepValid)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
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
                .font(AppTypography.heroInput) // Use standardized Hero font
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding()
                .background(Color.clear)
        }
    }
    
    private var limitStep: some View {
        VStack(spacing: 16) {
            Text("Budget Limit")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("Optional", text: $amountString)
                .font(AppTypography.heroRounded(size: 64))
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
                .padding(.vertical, 20)
            }
        }
    }
}



struct AccountStep: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var errorMessage: String?
    var focusedField: FocusState<OnboardingView.Field?>.Binding
    var onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Create your account")
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                    .focused(focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField.wrappedValue = .password
                    }
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                CustomSecureField(icon: "lock.fill", placeholder: "Password (min 6 chars)", text: $password)
                    .focused(focusedField, equals: .password)
                    .submitLabel(.join)
                    .onSubmit {
                        if email.contains("@") && password.count >= 6 {
                            onSubmit()
                        }
                    }
            }
            .padding(.horizontal, AppSpacing.section)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.section)
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

