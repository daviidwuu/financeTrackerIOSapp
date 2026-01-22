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
                        case 3: IncomeStep(income: $incomeInput)
                        case 4: CategoriesStep(categories: $onboardingCategories)
                        case 5: SavingGoalsStep(goals: $onboardingSavingGoals)
                        case 6: AccountStep(email: $emailInput, password: $passwordInput, errorMessage: $errorMessage)
                        default: EmptyView()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: direction),
                        removal: .move(edge: direction == .leading ? .trailing : .leading)
                    ))
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
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(currentStep == 6 ? "Create Account" : "Continue")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isStepValid ? Color.white : Color.gray.opacity(0.3))
                    .foregroundColor(.black)
                    .cornerRadius(AppRadius.button)
                    .disabled(!isStepValid || isLoading)
                }
                .padding(24)
                // Add background to buttons to prevent content overlap
                .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.9)) 
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Logic
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1: return true
        case 2: return !nameInput.isEmpty
        case 3: return Double(incomeInput) != nil || incomeInput.isEmpty
        case 4: return !onboardingCategories.filter { $0.isSelected }.isEmpty
        case 5: return true // Optional to have saving goals
        case 6: return !emailInput.isEmpty && !passwordInput.isEmpty && emailInput.contains("@") && passwordInput.count >= 6
        default: return false
        }
    }
    
    private func nextStep() {
        hideKeyboard()
        if currentStep < 6 {
            direction = .trailing
            HapticManager.shared.light() // Navigation haptic
            withAnimation { currentStep += 1 }
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
            withAnimation { currentStep -= 1 }
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
                let result = try await FirebaseManager.shared.signUp(email: emailInput, password: passwordInput, name: nameInput)
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
                    appState.userEmail = emailInput
                    appState.currentUserId = userId
                    appState.isUserLoggedIn = true
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
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(.white)
                .padding()
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 160, height: 160)
                )
            
            VStack(spacing: 12) {
                Text("Welcome to Finance Tracker")
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
            }

        }
            .overlay {
                if showSwipeGuide {
                    SwipeGuideView(onDismiss: {
                        withAnimation {
                            showSwipeGuide = false
                            hasShownGuide = true
                        }
                    })
                }
            }
            .onAppear {
                if !hasShownGuide {
                    // Slight delay to allow view to appear fully
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            showSwipeGuide = true
                        }
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
                .presentationDetents([.fraction(0.85)]) // Increased height for custom UI
                .presentationDragIndicator(.visible)
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
                        withAnimation { currentStep += 1 }
                    } else {
                        HapticManager.shared.success()
                        saveChanges()
                    }
                }) {
                    Text(currentStep < 4 ? "Next" : "Save Changes")
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
            // Initialize state
            currentStep = initialStep
            name = category.name
            selectedIcon = category.icon
            selectedColorHex = category.colorHex
            if let amount = category.budgetAmount {
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
                                    withAnimation {
                                        goals[index].isSelected.toggle()
                                    }
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
                        withAnimation { currentStep += 1 }
                    } else {
                        HapticManager.shared.success()
                        saveChanges()
                    }
                }) {
                    Text(currentStep < 5 ? "Next" : "Save Changes")
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

#Preview {
    OnboardingView()
}
