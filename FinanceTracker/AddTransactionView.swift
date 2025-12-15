import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var transactionToEdit: Transaction?
    var onSave: ((Transaction) -> Void)?
    
    @State private var currentStep = 1
    @State private var amount: String = ""
    @State private var selectedCategory: String = "Food"
    @State private var date = Date()
    @State private var notes: String = ""
    @State private var direction: Edge = .trailing
    
    let categories = ["Food", "Transport", "Shopping", "Entertainment", "Health", "Bills", "Other"]
    
    init(transactionToEdit: Transaction? = nil, onSave: ((Transaction) -> Void)? = nil) {
        self.transactionToEdit = transactionToEdit
        self.onSave = onSave
        
        if let transaction = transactionToEdit {
            _amount = State(initialValue: transaction.amount.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "$", with: ""))
            _selectedCategory = State(initialValue: transaction.subtitle) // Assuming subtitle maps to category for now
            _date = State(initialValue: transaction.date)
            _notes = State(initialValue: transaction.notes)
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
                    if currentStep < 3 {
                        direction = .trailing
                        withAnimation { currentStep += 1 }
                    } else {
                        saveTransaction()
                    }
                }) {
                    Text(currentStep < 3 ? "Next" : (transactionToEdit != nil ? "Update Transaction" : "Save Transaction"))
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
    
    private func saveTransaction() {
        let newTransaction = Transaction(
            title: selectedCategory, // Using category as title for simplicity
            subtitle: selectedCategory,
            amount: "-\(amount)", // Assuming expense
            icon: "cart.fill", // Default icon
            color: .blue, // Default color
            date: date,
            notes: notes
        )
        
        if var transaction = transactionToEdit {
            transaction.amount = "-\(amount)"
            transaction.subtitle = selectedCategory
            transaction.date = date
            transaction.notes = notes
            onSave?(transaction)
        } else {
            onSave?(newTransaction)
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
            return true
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
    
    private var detailsStep: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Category")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: { selectedCategory = category }) {
                            Text(category)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(selectedCategory == category ? Color.primary : Color.secondary.opacity(0.1))
                                .foregroundColor(selectedCategory == category ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Date")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
        }
    }
    
    private var notesStep: some View {
        VStack(spacing: 16) {
            Text("Notes (Optional)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField("e.g. Lunch with friends", text: $notes)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .submitLabel(.done)
        }
    }
}

#Preview {
    AddTransactionView()
}
