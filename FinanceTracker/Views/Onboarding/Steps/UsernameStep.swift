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
                .font(.body)
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
                                .font(.caption)
                        } else {
                            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isAvailable ? AppColors.functionalIncome : AppColors.functionalExpense)
                            Text(availabilityMessage)
                                .font(.caption)
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
        
        guard name.count >= 3 else {
            isAvailable = false
            availabilityMessage = "Too short"
            return
        }
        
        isChecking = true
        // Simple debounce by delaying task
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if Task.isCancelled { return }
            
            do {
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
