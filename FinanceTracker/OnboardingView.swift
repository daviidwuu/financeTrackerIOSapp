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
    @State private var incomeInput = "5000" // Added incomeInput
    @State private var emailInput = ""
    @State private var passwordInput = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Categories
    @State private var onboardingCategories: [OnboardingCategory] = [
        OnboardingCategory(name: "Food & Drink", icon: "fork.knife", colorHex: "#FF9500"),
        OnboardingCategory(name: "Transport", icon: "car.fill", colorHex: "#007AFF"),
        OnboardingCategory(name: "Bills", icon: "doc.text.fill", colorHex: "#FF3B30"),
        OnboardingCategory(name: "Shopping", icon: "bag.fill", colorHex: "#AF52DE"),
        OnboardingCategory(name: "Entertainment", icon: "tv.fill", colorHex: "#5856D6"),
        OnboardingCategory(name: "Salary", icon: "dollarsign.circle.fill", colorHex: "#34C759", isSelected: true, budgetAmount: nil) // Added Salary
    ]
    
    @AppStorage("monthlyIncome") private var monthlyIncome = 5000.0
    
    struct OnboardingCategory: Identifiable {
        let id = UUID()
        var name: String
        var icon: String
        var colorHex: String
        var isSelected: Bool = true
        var budgetAmount: Double? = nil
    }
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Bar
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { step in
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
                TabView(selection: $currentStep) {
                    IntroStep().tag(1)
                    ProfileStep(name: $nameInput).tag(2)
                    IncomeStep(income: $incomeInput).tag(3) // Renamed from BudgetStep
                    CategoriesStep(categories: $onboardingCategories).tag(4)
                    AccountStep(email: $emailInput, password: $passwordInput, errorMessage: $errorMessage).tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                .transition(.slide)
                
                Spacer()
                
                // Navigation Buttons
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
                            Text(currentStep == 5 ? "Create Account" : "Continue")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isStepValid ? Color.white : Color.gray.opacity(0.3))
                    .foregroundColor(.black)
                    .cornerRadius(25)
                    .disabled(!isStepValid || isLoading)
                }
                .padding(24)
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Logic
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1: return true
        case 2: return !nameInput.isEmpty
        case 3: return Double(incomeInput) != nil // Updated for incomeInput
        case 4: return !onboardingCategories.filter { $0.isSelected }.isEmpty
        case 5: return !emailInput.isEmpty && !passwordInput.isEmpty && emailInput.contains("@") && passwordInput.count >= 6
        default: return false
        }
    }
    
    private func nextStep() {
        if currentStep < 5 {
            withAnimation { currentStep += 1 }
        } else {
            completeOnboarding()
        }
    }
    
    private func prevStep() {
        if currentStep > 1 {
            withAnimation { currentStep -= 1 }
        }
    }
    
    private func completeOnboarding() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Create Account
                let result = try await FirebaseManager.shared.signUp(email: emailInput, password: passwordInput, name: nameInput)
                let userId = result.uid
                
                // 3. Save Income & Create Recurring Transaction
                await MainActor.run {
                    let income = Double(incomeInput) ?? 5000.0
                    self.monthlyIncome = income
                }
                
                // Create Recurring Income Transaction
                let recurringIncome = FirestoreModels.RecurringTransaction(
                    id: UUID().uuidString,
                    name: "Monthly Income",
                    amount: Double(incomeInput) ?? 5000.0,
                    frequency: "Monthly",
                    startDate: Date(),
                    icon: "dollarsign.circle.fill",
                    colorHex: "#34C759", // Green
                    note: "Auto-generated from onboarding",
                    userId: userId,
                    createdAt: Date()
                )
                let recurringRef = Firestore.firestore().collection("users").document(userId).collection("recurring").document(recurringIncome.id!)
                try await recurringRef.setData(from: recurringIncome)
                
                // 4. Create Categories in Firestore
                let db = Firestore.firestore()
                // Use all categories in the list
                let selectedCategories = onboardingCategories
                
                let batch = db.batch()
                
                for cat in selectedCategories {
                    // Create Category
                    let newCategory = FirestoreModels.Category(
                        id: UUID().uuidString,
                        name: cat.name,
                        icon: cat.icon,
                        colorHex: cat.colorHex,
                        type: "expense",
                        userId: userId,
                        createdAt: Date()
                    )
                    
                    let catRef = db.collection("users").document(userId).collection("categories").document(newCategory.id!)
                    try batch.setData(from: newCategory, forDocument: catRef)
                    
                    // Create Budget if amount is set
                    if let amount = cat.budgetAmount, amount > 0 {
                        let newBudget = FirestoreModels.CategoryBudget(
                            id: UUID().uuidString,
                            category: cat.name, // Linking by name for now as per simple model
                            totalAmount: amount,
                            icon: cat.icon,
                            colorHex: cat.colorHex,
                            frequency: "monthly",
                            userId: userId,
                            monthStartDate: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!,
                            createdAt: Date()
                        )
                        let budgetRef = db.collection("users").document(userId).collection("budgets").document(newBudget.id!)
                        try batch.setData(from: newBudget, forDocument: budgetRef)
                    }
                }
                
                try await batch.commit()
                
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
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.black)
                .cornerRadius(16)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

struct IncomeStep: View { // Renamed from BudgetStep
    @Binding var income: String // Renamed from budget
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green) // Green for income
                .padding(.bottom, 20)
            
            Text("What is your monthly income?") // Updated UI text
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                TextField("5000", text: $income) // Updated binding
                    .keyboardType(.numberPad)
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .fixedSize()
            }
            
            Text("This will be set as your recurring monthly income.") // Updated UI text
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
                        } else {
                            Text("Set Budget")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
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
                        categoryToEdit = category
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            if let index = categories.firstIndex(where: { $0.id == category.id }) {
                                categories.remove(at: index)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            categoryToEdit = category
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        .tint(.white)
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
            .sheet(item: $categoryToEdit) { category in
                EditCategorySheet(
                    category: category,
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
    let icons = [
        "cart.fill", "car.fill", "bag.fill", "tv.fill", "doc.text.fill", "heart.fill", 
        "house.fill", "bolt.fill", "tag.fill", "star.fill", "dollarsign.circle.fill", "briefcase.fill",
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill", "wineglass.fill",
        "bus.fill", "airplane", "bicycle", "fuelpump.fill",
        "tshirt.fill", "eyeglasses", "cart.badge.plus", "giftcard.fill",
        "film.fill", "music.note", "headphones", "gamecontroller.fill",
        "dumbbell.fill", "figure.walk", "sportscourt.fill", "soccerball",
        "cross.case.fill", "pills.fill", "stethoscope", "heart.text.square.fill",
        "book.fill", "graduationcap.fill", "pencil", "backpack.fill",
        "creditcard.fill", "chart.line.uptrend.xyaxis", "banknote.fill", "percent",
        "wrench.and.screwdriver.fill", "hammer.fill", "paintbrush.fill", "lightbulb.fill"
    ]
    let colors: [Color] = [.orange, .blue, .purple, .red, .green, .pink, .yellow, .gray, .mint, .indigo]
    
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
                        Button(action: { selectedIcon = icon }) {
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
                        Button(action: { selectedColorHex = hex }) {
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

#Preview {
    OnboardingView()
}
