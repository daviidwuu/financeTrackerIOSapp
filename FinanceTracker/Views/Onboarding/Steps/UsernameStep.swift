import SwiftUI

struct UsernameStep: View {
    @Binding var username: String
    var focusedField: FocusState<OnboardingView.Field?>.Binding
    var onNext: () -> Void
    @State private var isChecking = false
    @State private var availabilityMessage = ""
    @State private var isAvailable = false
    @State private var checkTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Pick a Username")
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
            
            Text("Friends can use this to find you.")
                .font(AppTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                TextField("username", text: $username)
                    .focused(focusedField, equals: .username)
                    .onSubmit {
                        if !username.isEmpty && username.count >= 3 && isAvailable {
                            onNext()
                        }
                    }
                    .font(AppTypography.heroInput)
                    .multilineTextAlignment(.center)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color.clear)
                    .padding(.horizontal, AppSpacing.section)
                    .onChange(of: username) { _, newValue in
                        checkAvailability(newValue)
                    }
                
                if !username.isEmpty {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .font(AppTypography.caption)
                        } else {
                            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isAvailable ? AppColors.functionalIncome : AppColors.functionalExpense)
                            Text(availabilityMessage)
                                .font(AppTypography.caption)
                                .foregroundColor(isAvailable ? AppColors.functionalIncome : AppColors.functionalExpense)
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func checkAvailability(_ name: String) {
        checkTask?.cancel()
        
        // FIX #23: Trim whitespace before validation
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            isAvailable = false
            availabilityMessage = trimmed.isEmpty ? "Required" : "Too short"
            return
        }
        
        isChecking = true
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if Task.isCancelled { return }
            
            do {
                try? await FirebaseManager.shared.signInAnonymously()
                
                let available = try await FirebaseManager.shared.checkUsernameAvailability(name)
                await MainActor.run {
                    isChecking = false
                    isAvailable = available
                    availabilityMessage = available ? "Available" : "Taken"
                }
            } catch {
                await MainActor.run {
                    isChecking = false
                    isAvailable = false
                    availabilityMessage = "Error checking"
                }
            }
        }
    }
}
