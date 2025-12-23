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
    let colors: [Color] = [
        .orange, .blue, .purple, .red, .green, .pink, .yellow, .gray,
        .cyan, .indigo, .mint, .teal, .brown
    ]
    let frequencies = ["Weekly", "Bi-Weekly", "Monthly", "Yearly"]
    
    init(budgetToEdit: FirestoreModels.CategoryBudget? = nil, onSave: ((Budget) -> Void)? = nil) {
        self.budgetToEdit = budgetToEdit
        self.onSave = onSave
        
        if let budget = budgetToEdit {
            _amount = State(initialValue: String(format: "%.2f", budget.totalAmount))
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
                    title: currentStep < 6 ? "Add Budget" : "Confirm",
                    currentStep: currentStep,
                    totalSteps: 6,
                    onBack: currentStep > 1 ? {
                        direction = .leading
                        withAnimation { currentStep -= 1 }
                    } : nil,
                    onClose: { dismiss() }
                )
                
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
                .padding(.horizontal, AppSpacing.margin)
                
                Spacer()
                
                // Sticky Action Bar
                VStack {
                    Button(action: {
                        if currentStep < 6 { // Increased steps to 6
                            HapticManager.shared.light()
                            direction = .trailing
                            withAnimation { currentStep += 1 }
                        } else {
                            HapticManager.shared.success()
                            saveBudget()
                        }
                    }) {
                        Text(currentStep < 6 ? "Next" : (budgetToEdit != nil ? "Update Budget" : "Save Budget"))
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
                .background(Color(UIColor.systemBackground))
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
            return true // Type step always valid
        case 2:
            if let value = Double(amount), value > 0 {
                return true
            }
            return false
        case 3:
            return !name.isEmpty
        case 4:
            return true
        case 5:
            return true
        case 6:
            return true
        default:
            return false
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        if currentStep == 1 {
            typeStep
        } else if currentStep == 2 {
            limitStep
        } else if currentStep == 3 {
            nameStep
        } else if currentStep == 4 {
            iconStep
        } else if currentStep == 5 {
            colorStep
        } else {
            periodStep
        }
    }
    
    private var typeStep: some View {
        VStack(spacing: 24) {
            Text("Income or Expense?")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                Button(action: { type = "income" }) {
                    VStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(type == "income" ? .white : .green)
                        Text("Income")
                            .fontWeight(.bold)
                    }
                    .frame(width: 140, height: 140)
                    .background(type == "income" ? Color.green : Color(UIColor.secondarySystemBackground))
                    .foregroundColor(type == "income" ? .white : .primary)
                    .cornerRadius(AppRadius.medium)
                }
                
                Button(action: { type = "expense" }) {
                    VStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(type == "expense" ? .white : .red)
                        Text("Expense")
                            .fontWeight(.bold)
                    }
                    .frame(width: 140, height: 140)
                    .background(type == "expense" ? Color.red : Color(UIColor.secondarySystemBackground))
                    .foregroundColor(type == "expense" ? .white : .primary)
                    .cornerRadius(AppRadius.medium)
                }
            }
        }
    }
    
    private var limitStep: some View {
        VStack(spacing: 16) {
            Text(type == "income" ? "Expected Income" : "Budget Limit") // Dynamic text
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("0.00", text: $amount)
                .font(AppTypography.heroInput)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
        }
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
                .padding(.horizontal, AppSpacing.margin)
            }
        }
    }
    
    private var colorStep: some View {
        VStack(spacing: 24) {
            Text("Select Color")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
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
    }
}

#Preview {
    AddBudgetView()
}
