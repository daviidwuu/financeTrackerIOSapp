import SwiftUI

struct IncomeStep: View {
    @Binding var income: String
    var focusedField: FocusState<OnboardingView.Field?>.Binding
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppColors.functionalIncome.opacity(0.1))
                    .frame(width: 160, height: 160)
                
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.functionalIncome)
            }
            .padding(.bottom, 20)
            
            Text("What is your monthly income?")
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(AppTypography.heroRounded(size: 40))
                    .foregroundColor(.secondary)
                
                TextField("0", text: $income)
                    .focused(focusedField, equals: .income)
                    .keyboardType(.numberPad)
                    .font(AppTypography.heroInput)
                    .multilineTextAlignment(.leading)
                    .fixedSize()
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            if focusedField.wrappedValue == .income {
                                Spacer()
                                Button("Done") {
                                    focusedField.wrappedValue = nil
                                }
                            }
                        }
                    }
            }
            
            Text("This will be set as your recurring monthly salary.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}
