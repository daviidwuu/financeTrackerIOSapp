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
    @State private var selectedColor: Color = .blue
    @State private var targetDate = Date()
    @State private var direction: Edge = .trailing
    
    // Sticky Modal Logic
    @State private var presentationDetent: PresentationDetent = .medium
    
    let icons = AppConstants.allIcons
    let colors = AppConstants.allColors
    
    init(goalToEdit: FirestoreModels.SavingGoal? = nil, onSave: ((SavingGoal) -> Void)? = nil) {
        self.goalToEdit = goalToEdit
        self.onSave = onSave
        
        if let goal = goalToEdit {
            _amount = State(initialValue: String(format: "%.2f", goal.targetAmount))
            _goalName = State(initialValue: goal.name)
            _selectedIcon = State(initialValue: goal.icon)
            _selectedColor = State(initialValue: Color(hex: goal.colorHex))
            _targetDate = State(initialValue: goal.targetDate)
        }
    }
    
    var body: some View {
        ZStack {
            // ... (rest of body stays same until saveGoal)
            // Background
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                ModalHeader(
                    title: headerTitle,
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
                
                // Sticky Action Bar
                VStack {
                    Button(action: {
                        if currentStep < 5 {
                            HapticManager.shared.light()
                            direction = .trailing
                            withAnimation { currentStep += 1 }
                        } else {
                            HapticManager.shared.success()
                            saveGoal()
                        }
                    }) {
                        Text(currentStep < 5 ? "Next" : (goalToEdit != nil ? "Update Goal" : "Save Goal"))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isStepValid ? Color.primary : Color.primary.opacity(0.3))
                            .cornerRadius(AppRadius.button)
                    }
                    .disabled(!isStepValid)
                }
                .padding(AppSpacing.margin)
                .background(Color.backgroundPrimary)
            }
        }
        .presentationDetents([.medium, .large], selection: $presentationDetent)
        .presentationDragIndicator(.visible)
    }
    
    private var headerTitle: String {
        switch currentStep {
        case 1: return "Target Amount"
        case 2: return "Goal Name"
        case 3: return "Select Icon"
        case 4: return "Select Color"
        case 5: return "Target Date"
        default: return ""
        }
    }
    
    private func saveGoal() {
        guard let targetAmount = Double(amount) else { return }
        
        let newGoal = SavingGoal(
            name: goalName,
            currentAmount: 0,
            targetAmount: targetAmount,
            icon: selectedIcon,
            color: selectedColor,
            targetDate: targetDate
        )
        
        if let goal = goalToEdit {
            let updatedGoal = SavingGoal(
                name: goalName,
                currentAmount: goal.currentAmount,
                targetAmount: targetAmount,
                icon: selectedIcon,
                color: selectedColor,
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
            return !goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            amountStep
        } else if currentStep == 2 {
            nameStep
        } else if currentStep == 3 {
            iconStep
        } else if currentStep == 4 {
            colorStep
        } else {
            dateStep
        }
    }
    
    private var amountStep: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("How much needed?")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("0.00", text: $amount)
                .font(AppTypography.heroInput)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.margin)
    }
    
    private var nameStep: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("What are you saving for?")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("e.g. New Car", text: $goalName)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .submitLabel(.done)
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.margin)
    }
    
    private var iconStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 20) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: {
                            HapticManager.shared.light()
                            selectedIcon = icon
                        }) {
                            Circle()
                                .fill(selectedIcon == icon ? selectedColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? selectedColor : .primary)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor, lineWidth: selectedIcon == icon ? 2 : 0)
                                )
                        }
                    }
                }
            }
            .padding(.bottom, 100)
            .padding(.horizontal, AppSpacing.compact)
        }
    }
    
    private var colorStep: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                                    Image(systemName: "checkmark")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .opacity(selectedColor == color ? 1 : 0)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                )
                        }
                    }
                }
            }
            .padding(.bottom, 100)
            .padding(.horizontal, AppSpacing.compact)
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
                .cornerRadius(AppRadius.medium)
                .tint(selectedColor)
        }
        .padding(.horizontal, AppSpacing.margin)
    }
}

#Preview {
    AddSavingGoalView()
}
