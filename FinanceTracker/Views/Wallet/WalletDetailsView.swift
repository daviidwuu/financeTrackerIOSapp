import SwiftUI

struct WalletDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Binding var initialBalance: Double
    
    let totalBalance: Double
    let aggregatedIncome: Double
    let aggregatedExpense: Double
    
    @State private var amount: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ModalHeader(
                    title: "Wallet Details",
                    currentStep: 1,
                    totalSteps: 1,
                    onBack: nil,
                    onClose: { dismiss() }
                )
                .padding()
                
                ScrollView {
                    VStack(spacing: AppSpacing.section) {
                        
                        // Hero Section
                        VStack(spacing: 12) {
                            Text(String(format: "$%.2f", totalBalance))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(totalBalance >= 0 ? .primary : .red)
                            
                            Text("Total Balance")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        
                        // All-Time Statistics Grid
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ALL TIME")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 0) {
                                // Income
                                DetailRow(title: "Total Income", amount: aggregatedIncome, color: .green)
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                // Expense
                                DetailRow(title: "Total Spent", amount: aggregatedExpense, color: .red)
                            }
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                        }
                        
                        // Edit Balance Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("STARTING BALANCE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 12) {
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
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                
                                Text("This base amount is added to your calculated total.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 16)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                            .onTapGesture { HapticManager.shared.light()
                                isFocused = true
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.bottom, AppSpacing.margin)
                }
                
                // Save Button
                Button(action: saveBalance) {
                    Text("Save Changes")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(amount.isEmpty)
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            if initialBalance != 0 {
                amount = String(format: "%.2f", initialBalance)
            }
        }
    }
    
    private func saveBalance() {
        if let value = CurrencyInput.parse(amount) {
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
        HStack(spacing: 16) {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("$\(String(format: "%.2f", amount))")
                .font(.body)
                .foregroundColor(color)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}
