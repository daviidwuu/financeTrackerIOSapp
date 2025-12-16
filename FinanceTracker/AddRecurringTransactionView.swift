import SwiftUI

struct AddRecurringTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var recurringToEdit: FirestoreModels.RecurringTransaction?
    var onSave: ((RecurringTransaction) -> Void)?
    
    @State private var currentStep = 1
    @State private var amount: String = ""
    @State private var name: String = ""
    @State private var selectedIcon: String = "house.fill"
    @State private var selectedColor: Color = .blue
    @State private var frequency: String = "Monthly"
    @State private var notes: String = ""
    @State private var direction: Edge = .trailing
    
    let icons = ["house.fill", "tv.fill", "car.fill", "bolt.fill", "drop.fill", "phone.fill", "wifi", "cart.fill"]
    let colors: [Color] = [.blue, .red, .orange, .green, .purple, .pink, .yellow, .gray]
    let frequencies = ["Weekly", "Bi-Weekly", "Monthly", "Yearly"]
    
    init(recurringToEdit: FirestoreModels.RecurringTransaction? = nil, onSave: ((RecurringTransaction) -> Void)? = nil) {
        self.recurringToEdit = recurringToEdit
        self.onSave = onSave
        
        if let transaction = recurringToEdit {
            _amount = State(initialValue: String(format: "%.2f", transaction.amount))
            _name = State(initialValue: transaction.name)
            _selectedIcon = State(initialValue: transaction.icon)
            _selectedColor = State(initialValue: Color(hex: transaction.colorHex))
            _frequency = State(initialValue: transaction.frequency)
            _notes = State(initialValue: transaction.note ?? "")
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
                    
                    Text("Step \(currentStep) of 6")
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
                    if currentStep < 6 {
                        HapticManager.shared.light()
                        direction = .trailing
                        withAnimation { currentStep += 1 }
                    } else {
                        HapticManager.shared.success()
                        saveRecurring()
                    }
                }) {
                    Text(currentStep < 6 ? "Next" : (recurringToEdit != nil ? "Update Recurring" : "Save Recurring"))
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
    
    private func saveRecurring() {
        guard let amountValue = Double(amount) else { return }
        
        let newRecurring = RecurringTransaction(
            name: name,
            amount: amountValue,
            icon: selectedIcon,
            color: selectedColor,
            frequency: frequency,
            notes: notes
        )
        
        if let _ = recurringToEdit {
            // Update logic handled by parent
            onSave?(newRecurring)
        } else {
            onSave?(newRecurring)
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
        case 6:
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
        } else if currentStep == 5 {
            frequencyStep
        } else {
            notesStep
        }
    }
    
    private var amountStep: some View {
        VStack(spacing: 16) {
            Text("Amount")
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
    
    private var frequencyStep: some View {
        VStack(spacing: 16) {
            Text("Frequency")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Picker("Frequency", selection: $frequency) {
                ForEach(frequencies, id: \.self) { freq in
                    Text(freq).tag(freq)
                }
            }
            .pickerStyle(.wheel)
        }
    }
    
    private var notesStep: some View {
        VStack(spacing: 16) {
            Text("Notes (Optional)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("e.g. Monthly Rent", text: $notes)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .submitLabel(.done)
        }
    }
}

#Preview {
    AddRecurringTransactionView()
}
