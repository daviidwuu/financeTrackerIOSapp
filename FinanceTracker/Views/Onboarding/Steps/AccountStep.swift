import SwiftUI

struct AccountStep: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var errorMessage: String?
    var focusedField: FocusState<OnboardingView.Field?>.Binding
    var onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Create your account")
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
            
            Text("Your data is securely stored and never shared.")
                .font(AppTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.section)
            
            VStack(spacing: 16) {
                CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                    .focused(focusedField, equals: .email)
                    .onSubmit {
                        focusedField.wrappedValue = .password
                    }
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                CustomSecureField(icon: "lock.fill", placeholder: "Password (min 6 chars)", text: $password)
                    .focused(focusedField, equals: .password)
                    .onSubmit {
                        if email.contains("@") && password.count >= 6 {
                            onSubmit()
                        }
                    }
            }
            .padding(.horizontal, AppSpacing.section)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(AppColors.functionalExpense)
                    .font(AppTypography.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.section)
            }
            
            Spacer()
        }
    }
}
