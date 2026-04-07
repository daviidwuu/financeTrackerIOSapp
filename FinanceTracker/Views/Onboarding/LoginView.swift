import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    enum Field: Hashable {
        case email
        case password
    }
    
    @FocusState private var focusedField: Field?
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showForgotPassword = false
    
    // Add method to dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Welcome Back")
                        .font(AppTypography.heroRounded(size: 28))
                        .foregroundColor(.primary)
                    
                    Text("Sign in to continue")
                        .font(AppTypography.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Form
                VStack(spacing: 20) {
                    CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    CustomSecureField(icon: "lock.fill", placeholder: "Password", text: $password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.join)
                        .onSubmit {
                            if isFormValid { login() }
                        }
                    
                    HStack {
                        Spacer()
                        Button("Forgot Password?") { HapticManager.shared.light(); 
                            showForgotPassword = true
                        }
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.brandPrimary)
                    }
                }
                .padding(.horizontal, AppSpacing.section)
                
                if showError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(errorMessage)
                    }
                    .foregroundColor(AppColors.functionalExpense)
                    .font(AppTypography.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.section)
                    .transition(.opacity)
                }
                
                Spacer()
                
                // Action Button
                Button(action: login) {
                    Text("Log In")
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal, AppSpacing.section)
                .padding(.bottom, AppSpacing.margin)
            }
        }
        .onTapGesture { HapticManager.shared.light(); 
            hideKeyboard()
        }
        .onAppear {
            // Auto focus email field when login view opens
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .email
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Password", isPresented: $showForgotPassword) {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            Button("Send Reset Link") { HapticManager.shared.light(); 
                resetPassword()
            }
            Button("Cancel", role: .cancel) { HapticManager.shared.light();  }
        } message: {
            Text("Enter your email address to receive a password reset link.")
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private func login() {
        isLoading = true
        showError = false
        
        Task {
            do {
                let _ = try await FirebaseManager.shared.signIn(email: email, password: password)
                // Firebase auth state listener in AppState will handle the rest
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    private func resetPassword() {
        guard !email.isEmpty else { return }
        Task {
            try? await FirebaseManager.shared.sendPasswordReset(email: email)
        }
    }
}

// Helper Components
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            SecureField(placeholder, text: $text)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }
}

#Preview {
    LoginView()
}
