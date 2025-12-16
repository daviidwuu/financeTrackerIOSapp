import SwiftUI

struct EditBalanceView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var initialBalance: Double
    @State private var amount: String = ""
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        HapticManager.shared.light()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    
                    Spacer()
                    
                    Text("Initial Balance")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.clear)
                        .frame(width: 44, height: 44)
                }
                .padding()
                
                Spacer()
                
                // Content
                VStack(spacing: 24) {
                    Text("What's your starting balance?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("This will be used as your baseline to calculate your total balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Amount Input
                    HStack(spacing: 4) {
                        Text("$")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.primary)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Save Button
                Button(action: saveBalance) {
                    Text("Save Balance")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colorScheme == .dark ? Color.white : Color.black)
                        .cornerRadius(16)
                }
                .disabled(amount.isEmpty)
                .opacity(amount.isEmpty ? 0.6 : 1.0)
                .padding()
            }
        }
        .onAppear {
            if initialBalance > 0 {
                amount = String(format: "%.2f", initialBalance)
            }
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
