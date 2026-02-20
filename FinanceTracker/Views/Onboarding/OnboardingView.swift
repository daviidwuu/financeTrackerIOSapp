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
    

    
    // Saving Goals
    @State private var onboardingSavingGoals: [OnboardingSavingGoal] = [
        OnboardingSavingGoal(name: "Emergency Fund", targetAmount: 1000, icon: "lifepreserver.fill", colorHex: "#FF3B30"),
        OnboardingSavingGoal(name: "Vacation", targetAmount: 2000, icon: "airplane", colorHex: "#34C759"),
        OnboardingSavingGoal(name: "New Car", targetAmount: 20000, icon: "car.fill", colorHex: "#007AFF")
    ]
    

    
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
