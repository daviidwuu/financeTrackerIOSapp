import SwiftUI
import WidgetKit

struct AccountSettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @Environment(\.colorScheme) var colorScheme
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    
    // Username Check State
    @State private var isCheckingUsername = false
    @State private var usernameAvailable = true
    @State private var usernameMessage: String?
    @State private var initialUsername: String = ""
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)
                    
                    // Profile Information Section
                    MenuSection("Profile Information") {
                        MenuInputRow(title: "Name", text: $name, autocapitalization: .words)
                        MenuDivider()
                        
                        VStack(spacing: 0) {
                             MenuInputRow(title: "Username", text: $username, autocapitalization: .none)
                             
                             if isCheckingUsername {
                                 HStack {
                                     Spacer()
                                     Text("Checking availability...")
                                         .font(.caption)
                                         .foregroundColor(.secondary)
                                         .padding(.trailing, 16)
                                         .padding(.bottom, 8)
                                 }
                             } else if let msg = usernameMessage {
                                 HStack {
                                     Spacer()
                                     Text(msg)
                                         .font(.caption)
                                         .foregroundColor(usernameAvailable ? .green : .red)
                                         .padding(.trailing, 16)
                                         .padding(.bottom, 8)
                                 }
                             }
                        }
                        .onChange(of: username) { _, newValue in
                            checkUsername(newValue)
                        }

                        MenuDivider()
                        MenuInputRow(title: "Email", text: $email, keyboardType: .emailAddress, autocapitalization: .none)
                    }
                    .padding(.top, 0)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    // Actions
                    VStack {
                        Button(action: updateProfile) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                            } else {
                                Text("Update Profile")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colorScheme == .dark ? Color.white : Color.black)
                        .clipShape(Capsule())
                        .disabled(isLoading || name.isEmpty || email.isEmpty || username.isEmpty || !usernameAvailable || (name == appState.userName && email == appState.userEmail && username == initialUsername))
                        .opacity((isLoading || name.isEmpty || email.isEmpty || username.isEmpty || !usernameAvailable || (name == appState.userName && email == appState.userEmail && username == initialUsername)) ? 0.6 : 1)
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    
                    // Security
                    MenuSection("Security") {
                         Button(action: { sendPasswordReset() }) {
                             MenuRowView(icon: "lock.rotation", title: "Reset Password", showChevron: true)
                         }
                         
                    }
                    
                    // Danger Zone
                    MenuSection {
                        Button(action: { showDeleteConfirmation = true }) {
                            Text("Delete Account")
                                .font(.body)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            
            // Fixed Navigation Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 44, height: 44)
                        .background((colorScheme == .dark ? Color.white : Color.black).opacity(0.05))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Account Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Spacer()
                
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, AppSpacing.margin + AppSpacing.compact)
            .padding(.top, 16)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            name = appState.userName
            email = appState.userEmail
            username = appState.currentUserUsername
            initialUsername = appState.currentUserUsername
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
    
    private func checkUsername(_ input: String) {
        // Reset if empty or same as initial
        if input.isEmpty {
            usernameAvailable = false
            usernameMessage = "Username cannot be empty"
            return
        }
        
        if input == initialUsername {
            usernameAvailable = true
            usernameMessage = nil
            return
        }
        
        if input.count < 3 {
            usernameAvailable = false
            usernameMessage = "Min 3 characters"
            return
        }
        
        isCheckingUsername = true
        usernameMessage = nil
        
        // Debounce could be good, but for now direct check
        Task {
            do {
                let isAvailable = try await FirebaseManager.shared.checkUsernameAvailability(input)
                await MainActor.run {
                    self.isCheckingUsername = false
                    self.usernameAvailable = isAvailable
                    self.usernameMessage = isAvailable ? "Available" : "Taken"
                }
            } catch {
                await MainActor.run {
                    self.isCheckingUsername = false
                    self.usernameMessage = "Error checking"
                }
            }
        }
    }
    
    private func updateProfile() {
        guard !name.isEmpty, !email.isEmpty, !username.isEmpty, usernameAvailable else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                var firestoreUpdates: [String: Any] = [:]
                
                if name != appState.userName {
                    firestoreUpdates["name"] = name
                }
                
                // 1. Dedicated Username Call
                if username != initialUsername {
                    try await FirebaseManager.shared.updateUsername(userId: appState.currentUserId, oldUsername: initialUsername, newUsername: username)
                }
                
                if email != appState.userEmail {
                    // Update Auth email first
                    try await FirebaseManager.shared.updateEmail(email)
                    firestoreUpdates["email"] = email // Add to Firestore batch
                }
                
                // 2. Regular Profile Call (Batch Firestore update for name/email)
                if !firestoreUpdates.isEmpty {
                    try await FirebaseManager.shared.updateUserProfile(userId: appState.currentUserId, data: firestoreUpdates)
                }
                
                // 3. Update local AppState
                await MainActor.run {
                    if let newName = firestoreUpdates["name"] as? String {
                        appState.userName = newName
                    }
                    if username != initialUsername {
                        appState.currentUserUsername = username
                        initialUsername = username
                    }
                    if let newEmail = firestoreUpdates["email"] as? String {
                        appState.userEmail = newEmail
                    }
                    
                    isLoading = false
                    
                    // Dismiss the view upon successful update to show feedback
                    dismiss()
                }
            } catch let error as NSError {
                await MainActor.run {
                    isLoading = false
                    
                    // Handle specific Firebase Auth errors like requiresRecentLogin
                    if error.domain == "FIRAuthErrorDomain" && error.code == 17014 { // AuthErrorCode.requiresRecentLogin
                        errorMessage = "For security reasons, please log out and log back in to change your email."
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func deleteAccount() {
        isLoading = true
        Task {
            do {
                try await FirebaseManager.shared.deleteUser()
                // AppState listener will handle logout
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func sendPasswordReset() {
        Task {
            try? await FirebaseManager.shared.sendPasswordReset(email: email)
            // Show confirmation alert if needed
        }
    }
}

// MARK: - Appearance
