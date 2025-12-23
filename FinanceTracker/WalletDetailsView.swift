import SwiftUI

struct WalletDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Binding var initialBalance: Double
    
    let income: Double
    let expense: Double
    let netFlow: Double
    
    @State private var amount: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(
                title: "Wallet Details",
                currentStep: 1,
                totalSteps: 1,
                onBack: nil,
                onClose: { dismiss() }
            )
            
            ScrollView {
                VStack(spacing: AppSpacing.section) {
                    
                    // Monthly Statistics Grid
                    VStack(spacing: 16) {
                        HStack {
                            Text("This Month")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        VStack(spacing: 0) {
                            // Income
                            DetailRow(title: "Total Income", amount: income, color: .green)
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            // Expense
                            DetailRow(title: "Total Expense", amount: expense, color: .red)
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            // Net Flow
                            DetailRow(title: "Net Cash Flow", amount: netFlow, color: netFlow >= 0 ? .green : .red)
                        }
                        .background(Color.listBackground)
                        .cornerRadius(AppRadius.medium)
                    }
                    
                    // Edit Balance Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Starting Balance")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This amount is added to your calculated total.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("$")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .focused($isFocused)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .background(Color.listBackground)
                            .cornerRadius(AppRadius.medium)
                        }
                    }
                }
                .padding(AppSpacing.margin)
            }
            
            // Save Button
            Button(action: saveBalance) {
                Text("Save Changes")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(amount.isEmpty ? Color.gray : (colorScheme == .dark ? Color.white : Color.black))
                    .cornerRadius(AppRadius.button)
            }
            .disabled(amount.isEmpty)
            .padding(AppSpacing.margin)
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            amount = String(format: "%.2f", initialBalance)
        }
    }
    
    private func saveBalance() {
        if let value = Double(amount) {
            initialBalance = value
            HapticManager.shared.success()
            dismiss()
        }
    }
}

struct DetailRow: View {
    let title: String
    let amount: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text("$\(String(format: "%.2f", amount))")
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(16)
    }
}
