import SwiftUI

struct AddBudgetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var budgetToEdit: FirestoreModels.CategoryBudget?
    var onSave: ((BudgetFormData) -> Void)?
    
    @State private var currentStep = 1
    @State private var amount: String = ""
    @State private var name: String = ""
    @State private var selectedIcon: String = "cart.fill"
    @State private var selectedColor: Color = .orange
    @State private var frequency: String = "Monthly"
    @State private var type: String = "expense" // Added type
    @State private var direction: Edge = .trailing
    
    // Sticky Modal Logic
    @State private var presentationDetent: PresentationDetent = .medium
    @State private var availableDetents: Set<PresentationDetent> = [.medium, .large]
    
    let icons = AppConstants.allIcons
    let colors = AppConstants.allColors
    let frequencies = ["Weekly", "Bi-Weekly", "Monthly", "Yearly"]
    
    private func populateData() {
        if let budget = budgetToEdit {
            if budget.totalAmount != 0 {
                amount = String(format: "%.2f", budget.totalAmount)
            }
            name = budget.category
            selectedIcon = budget.icon
            selectedColor = Color(hex: budget.colorHex)
            frequency = budget.frequency
        }
    }
    
    var body: some View {
        WizardLayout(
            title: currentStep < 5 ? "Add Budget" : "Confirm",
            currentStep: currentStep,
            totalSteps: 5,
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
                // Sticky Logic: Enforce Large Detent
                availableDetents = [.large]
                presentationDetent = .large
                
                if currentStep < 5 {
                    HapticManager.shared.light()
                    direction = .trailing
                    withAnimation { currentStep += 1 }
                } else {
                    HapticManager.shared.success()
                    saveBudget()
                }
            }) {
                Text(currentStep < 5 ? "Next" : (budgetToEdit != nil ? "Update Budget" : "Save Budget"))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isStepValid)
            .animation(.easeInOut, value: isStepValid) // Smooth color transition
        }
        .presentationDetents(availableDetents, selection: $presentationDetent)
        .presentationDragIndicator(.visible)
        .onChange(of: presentationDetent) { _, newValue in
            // Sticky Logic: Once expanded to large, lock it there.
            if newValue == .large {
                availableDetents = [.large]
            }
        }
        .onAppear {
            populateData()
        }
    }
    
    private func saveBudget() {
        guard let totalAmount = CurrencyInput.parse(amount) else { return }
        
        let newBudget = BudgetFormData(
            category: name,
            remainingAmount: totalAmount, // Start full
            totalAmount: totalAmount,
            icon: selectedIcon,
            color: selectedColor,
            frequency: frequency,
            type: type // Added type
        )
        
        if let _ = budgetToEdit {
            // Update logic handled by parent
            onSave?(newBudget)
        } else {
            onSave?(newBudget)
            // Gamification
            GamificationManager.shared.completeMission(id: "budget_beginner")
            GamificationManager.shared.completeMission(id: "personalizer")
        }
        dismiss()
    }
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1:
            // Allow 0 for "No Limit"
            return CurrencyInput.parse(amount) != nil
        case 2:
            return !name.isEmpty
        case 3:
            return true
        case 4:
            return true
        case 5:
            return true
        default:
            return false
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        if currentStep == 1 {
            limitStep
        } else if currentStep == 2 {
            nameStep
        } else if currentStep == 3 {
            iconStep
        } else if currentStep == 4 {
            colorStep
        } else {
            periodStep
        }
    }
    

    
    private var limitStep: some View {
        VStack(spacing: 16) {
            Text("Budget Limit")
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
    
    private var nameStep: some View {
        VStack(spacing: 16) {
            Text("Category Name")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("e.g. Rent", text: $name) // Updated placeholder and binding to 'name'
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding()
                .background(Color.backgroundPrimary)
                .cornerRadius(AppRadius.medium)
        }
        .padding(.horizontal, AppSpacing.margin)
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
                            HapticManager.shared.light()
                            selectedIcon = icon
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
                .padding(.horizontal, AppSpacing.compact)
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
                        Button(action: {
                            HapticManager.shared.light()
                            selectedColor = color
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .opacity(selectedColor == color ? 1 : 0)
                                )
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, 20)
            }
        }
    }
    
    private var periodStep: some View {
        VStack(spacing: 16) {
            Text("Budget Period")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Picker("Frequency", selection: $frequency) { // Updated Picker label
                ForEach(frequencies, id: \.self) { p in
                    Text(p).tag(p)
                }
            }
            .pickerStyle(.wheel)
        }
        .padding(.horizontal, AppSpacing.margin)
    }
}

#Preview {
    AddBudgetView()
}
