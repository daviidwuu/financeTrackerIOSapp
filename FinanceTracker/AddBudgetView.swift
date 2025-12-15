import SwiftUI

struct AddBudgetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var budgetToEdit: Budget?
    var onSave: ((Budget) -> Void)?
    
    @State private var currentStep = 1
    @State private var amount: String = ""
    @State private var categoryName: String = ""
    @State private var selectedIcon: String = "cart.fill"
    @State private var selectedColor: Color = .blue
    @State private var selectedFrequency: String = "Monthly"
    @State private var direction: Edge = .trailing
    
    let icons = ["cart.fill", "car.fill", "house.fill", "bolt.fill", "gamecontroller.fill", "fork.knife", "cup.and.saucer.fill", "tshirt.fill", "cross.case.fill", "airplane"]
    let frequencies = ["Weekly", "Bi-Weekly", "Monthly", "Yearly"]
    let colors: [Color] = [.blue, .red, .green, .orange, .purple, .pink, .yellow, .mint, .teal, .indigo]
    
    init(budgetToEdit: Budget? = nil, onSave: ((Budget) -> Void)? = nil) {
        self.budgetToEdit = budgetToEdit
        self.onSave = onSave
        
        if let budget = budgetToEdit {
            _amount = State(initialValue: String(format: "%.2f", budget.totalAmount))
            _categoryName = State(initialValue: budget.category)
            _selectedIcon = State(initialValue: budget.icon)
            _selectedColor = State(initialValue: budget.color)
            _selectedFrequency = State(initialValue: budget.frequency)
        }
    }
    
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
                            direction = .leading
                            withAnimation { currentStep -= 1 }
                        } else {
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
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.clear)
                        .frame(width: 44, height: 44)
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
                        direction = .trailing
                        withAnimation { currentStep += 1 }
                    } else {
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
                        .cornerRadius(16)
                }
                .disabled(!isStepValid)
                .padding()
            }
        }
    }
    
    private func saveBudget() {
        let totalAmount = Double(amount) ?? 0.0
        let newBudget = Budget(
            category: categoryName,
            remainingAmount: totalAmount, // Start full
            totalAmount: totalAmount,
            icon: selectedIcon,
            color: selectedColor,
            frequency: selectedFrequency
        )
        
        if var budget = budgetToEdit {
            budget.category = categoryName
            budget.totalAmount = totalAmount
            budget.icon = selectedIcon
            budget.color = selectedColor
            budget.frequency = selectedFrequency
            onSave?(budget)
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
            return !categoryName.isEmpty
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
                .font(.system(size: 64, weight: .bold, design: .rounded))
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
            
            TextField("e.g. Groceries", text: $categoryName)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding()
                .background(Color.black)
                .cornerRadius(12)
        }
    }
    
    private var iconStep: some View {
        VStack(spacing: 24) {
            Text("Select Icon")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
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
            
            Picker("Period", selection: $selectedFrequency) {
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
