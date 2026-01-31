import SwiftUI
import FirebaseAuth

struct SetUsernameView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var username: String = ""
    @State private var isChecking = false
    @State private var availabilityMessage = ""
    @State private var isAvailable = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Pick a Username")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
                
                Text("Friends can use this to find you.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 8) {
                    TextField("username", text: $username)
                        .font(AppTypography.heroInput)
                        .multilineTextAlignment(.center)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 32)
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
                                    .foregroundColor(isAvailable ? .green : .red)
                                Text(availabilityMessage)
                                    .font(.caption)
                                    .foregroundColor(isAvailable ? .green : .red)
                            }
                        }
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                Button(action: saveUsername) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Save Username")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isAvailable && !isLoading ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(AppRadius.button)
                .disabled(!isAvailable || isLoading)
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func checkAvailability(_ name: String) {
        guard name.count >= 3 else {
            isAvailable = false
            availabilityMessage = "Too short"
            return
        }
        
        isChecking = true
        errorMessage = nil
        
        // Simple debounce
        Task {
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
    
    private func saveUsername() {
        guard isAvailable else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                guard let userId = FirebaseManager.shared.auth.currentUser?.uid else { return }
                try await FirebaseManager.shared.updateUserProfile(userId: userId, data: ["username": username])
                
                await MainActor.run {
                    appState.currentUserUsername = username
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
