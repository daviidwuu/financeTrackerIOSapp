import SwiftUI

struct ProfileStep: View {
    @Binding var name: String
    var focusedField: FocusState<OnboardingView.Field?>.Binding
    var onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("What should we call you?")
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
            
            TextField("Your Name", text: $name)
                .focused(focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit {
                    if !name.isEmpty {
                        onNext()
                    }
                }
                .font(AppTypography.heroInput)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.clear)
                .padding(.horizontal, AppSpacing.section)
            
            Spacer()
        }
    }
}
