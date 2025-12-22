import SwiftUI

struct EditBalanceView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var initialBalance: Double
    @State private var amount: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Drag Indicator spacer
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                
                Text("Starting Balance")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                // Amount Input
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .focused($isFocused)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: true, vertical: false) // Allow it to perform natural width
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
                
                Spacer()
                
                // Save Button
                Button(action: saveBalance) {
                    Text("Save Balance")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colorScheme == .dark ? Color.white : Color.black)
                        .cornerRadius(16)
                }
                .disabled(amount.isEmpty)
                .opacity(amount.isEmpty ? 0.6 : 1.0)
                .padding(.horizontal)
                .padding(.bottom) // Add standard bottom padding
            }
        }
        .onAppear {
            if initialBalance > 0 {
                amount = String(format: "%.2f", initialBalance)
            }
            // Delay focus slightly to ensure view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
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
