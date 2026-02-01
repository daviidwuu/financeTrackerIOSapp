import SwiftUI

struct AddBudgetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var budgetToEdit: FirestoreModels.CategoryBudget?
    var onSave: ((Budget) -> Void)?
    
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
    
    init(budgetToEdit: FirestoreModels.CategoryBudget? = nil, onSave: ((Budget) -> Void)? = nil) {
        self.budgetToEdit = budgetToEdit
        self.onSave = onSave
        
        if let budget = budgetToEdit {
            if budget.totalAmount != 0 {
                _amount = State(initialValue: String(format: "%.2f", budget.totalAmount))
            }
            _name = State(initialValue: budget.category)
            _selectedIcon = State(initialValue: budget.icon)
            _selectedColor = State(initialValue: Color(hex: budget.colorHex))
            _frequency = State(initialValue: budget.frequency)
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
                    title: currentStep < 5 ? "Add Budget" : "Confirm",
                    currentStep: currentStep,
                    totalSteps: 5,
                    onBack: currentStep > 1 ? {
                        direction = .leading
                        withAnimation { currentStep -= 1 }
                    } : nil,
                    onClose: { dismiss() }
                )
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, 16)
                
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
                
                Spacer()
                
                // Sticky Action Bar
                VStack {
                    Button(action: {
                        if currentStep < 5 { // Decreased steps to 5
                            HapticManager.shared.light()
                            direction = .trailing
                            withAnimation { currentStep += 1 }
                        } else {
                            HapticManager.shared.success()
                            saveBudget()
                        }
                    }) {
                        Text(currentStep < 5 ? "Next" : (budgetToEdit != nil ? "Update Budget" : "Save Budget"))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isStepValid ? Color.white : Color.white.opacity(0.3))
                            .cornerRadius(AppRadius.button)
                    }
                    .disabled(!isStepValid)
                }
                .padding(AppSpacing.margin)
                .background(Color.backgroundPrimary)
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
    }
    
    private func saveBudget() {
        guard let totalAmount = Double(amount) else { return }
        
        let newBudget = Budget(
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
                .foregroundColor(.white)
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
                        Button(action: { selectedColor = color }) {
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
