import SwiftUI

struct AddSavingGoalView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var goalToEdit: FirestoreModels.SavingGoal?
    var onSave: ((SavingGoal) -> Void)?
    
    @State private var currentStep = 1
    @State private var amount: String = ""
    @State private var goalName: String = ""
    @State private var selectedIcon: String = "car.fill"
    @State private var targetDate = Date()
    @State private var direction: Edge = .trailing
    
    let icons = ["car.fill", "house.fill", "airplane", "gift.fill", "graduationcap.fill", "display", "gamecontroller.fill", "cart.fill"]
    
    init(goalToEdit: FirestoreModels.SavingGoal? = nil, onSave: ((SavingGoal) -> Void)? = nil) {
        self.goalToEdit = goalToEdit
        self.onSave = onSave
        
        if let goal = goalToEdit {
            _amount = State(initialValue: String(format: "%.2f", goal.targetAmount))
            _goalName = State(initialValue: goal.name)
            _selectedIcon = State(initialValue: goal.icon)
            _targetDate = State(initialValue: goal.targetDate)
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
                    
                    Text("Step \(currentStep) of 3")
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
                
                // Content
                ScrollView {
                    ZStack(alignment: .top) {
                        currentStepView
                    }
                    .id(currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: direction),
                        removal: .move(edge: direction == .leading ? .trailing : .leading)
                    ))
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
                
                // Action Button
                Button(action: {
                    if currentStep < 3 {
                        HapticManager.shared.light()
                        direction = .trailing
                        withAnimation { currentStep += 1 }
                    } else {
                        HapticManager.shared.success()
                        saveGoal()
                    }
                }) {
                    Text(currentStep < 3 ? "Next" : (goalToEdit != nil ? "Update Goal" : "Save Goal"))
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
    
    private func saveGoal() {
        guard let targetAmount = Double(amount) else { return }
        
        let newGoal = SavingGoal(
            name: goalName,
            currentAmount: 0, // Start with 0 for new goals
            targetAmount: targetAmount,
            icon: selectedIcon,
            targetDate: targetDate
        )
        
        if let goal = goalToEdit {
            // Update logic handled by parent via onSave
            // We pass the updated struct back
            let updatedGoal = SavingGoal(
                name: goalName,
                currentAmount: goal.currentAmount,
                targetAmount: targetAmount,
                icon: selectedIcon,
                targetDate: targetDate
            )
            onSave?(updatedGoal)
        } else {
            onSave?(newGoal)
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
            return !goalName.isEmpty
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
            dateStep
        }
    }
    
    private var amountStep: some View {
        VStack(spacing: 16) {
            Text("Target Amount")
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
    
    private var detailsStep: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Goal Name")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("e.g. New Car", text: $goalName)
                    .font(.title3)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Icon")
                    .font(.headline)
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
    }
    
    private var dateStep: some View {
        VStack(spacing: 16) {
            Text("Target Date")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            DatePicker("", selection: $targetDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
        }
    }
}

#Preview {
    AddSavingGoalView()
}
