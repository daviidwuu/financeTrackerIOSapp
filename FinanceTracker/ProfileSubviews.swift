import SwiftUI

// MARK: - Account Settings
struct AccountSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var name: String = ""
    @State private var email: String = ""
    @Environment(\.colorScheme) var colorScheme
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Form {
            Section(header: Text("Profile Information")) {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section {
                Button(action: updateProfile) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Update Profile")
                    }
                }
                .disabled(isLoading || name.isEmpty || email.isEmpty || (name == appState.userName && email == appState.userEmail))
            }
            
            Section(header: Text("Password")) {
                Button("Reset Password") {
                    sendPasswordReset()
                }
            }
            
            Section {
                Button(action: { showDeleteConfirmation = true }) {
                    Text("Delete Account")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Account Settings")
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .scrollContentBackground(.hidden)
        .onAppear {
            name = appState.userName
            email = appState.userEmail
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
    
    private func updateProfile() {
        guard !name.isEmpty, !email.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if name != appState.userName {
                    try await FirebaseManager.shared.updateUserProfile(userId: appState.currentUserId, data: ["name": name])
                    await MainActor.run { appState.userName = name }
                }
                
                if email != appState.userEmail {
                    try await FirebaseManager.shared.updateEmail(email)
                    await MainActor.run { appState.userEmail = email }
                }
                
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
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
struct AppearanceSettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Display")) {
                Toggle("Dark Mode", isOn: $isDarkMode)
            }
        }
        .navigationTitle("Appearance")
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }
}


// MARK: - Notifications
struct NotificationsSettingsView: View {
    @AppStorage("notificationsEnabled_transactions") private var transactionNotifs = false
    @AppStorage("notificationsEnabled_budgets") private var budgetNotifs = false
    @AppStorage("notificationsEnabled_dailySummary") private var dailySummary = false
    @AppStorage("notificationsEnabled_weeklyReport") private var weeklyReport = false
    @Environment(\.colorScheme) var colorScheme
    
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingPermissionAlert = false
    
    var body: some View {
        Form {
            // Permission Status Section
            Section {
                HStack {
                    Image(systemName: permissionIcon)
                        .foregroundColor(permissionColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notification Permission")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(permissionText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if permissionStatus == .notDetermined || permissionStatus == .denied {
                        Button("Enable") {
                            requestPermission()
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                    }
                }
            }
            
            // Test Notification Button
            Section {
                Button(action: {
                    testNotification()
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundColor(.white)
                        Text("Send Test Notification")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Transaction Alerts
            Section(header: Text("Transaction Alerts"), footer: Text("Get notified when you add or edit transactions")) {
                Toggle("Transaction Notifications", isOn: $transactionNotifs)
                    .onChange(of: transactionNotifs) { newValue in
                        if newValue {
                            ensurePermission()
                        }
                    }
            }
            
            // Budget Alerts
            Section(header: Text("Budget Alerts"), footer: Text("Get warned when you reach 80% of your budget")) {
                Toggle("Budget Warnings", isOn: $budgetNotifs)
                    .onChange(of: budgetNotifs) { newValue in
                        if newValue {
                            ensurePermission()
                        }
                    }
            }
            
            // Scheduled Reports
            Section(header: Text("Scheduled Reports")) {
                Toggle("Daily Summary (9 PM)", isOn: $dailySummary)
                    .onChange(of: dailySummary) { newValue in
                        if newValue {
                            ensurePermission()
                            // Schedule will happen when user adds transactions
                        } else {
                            NotificationManager.shared.cancelDailySummary()
                        }
                    }
                
                Toggle("Weekly Report (Sunday 8 PM)", isOn: $weeklyReport)
                    .onChange(of: weeklyReport) { newValue in
                        if newValue {
                            ensurePermission()
                            NotificationManager.shared.scheduleWeeklyReport()
                        } else {
                            NotificationManager.shared.cancelWeeklyReport()
                        }
                    }
            }
        }
        .navigationTitle("Notifications")
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .scrollContentBackground(.hidden)
        .onAppear {
            checkPermissionStatus()
        }
        .alert("Open Settings", isPresented: $showingPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("To enable notifications, please allow them in Settings.")
        }
    }
    
    private var permissionIcon: String {
        switch permissionStatus {
        case .authorized, .provisional:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var permissionColor: Color {
        switch permissionStatus {
        case .authorized, .provisional:
            return .green
        case .denied:
            return .red
        default:
            return .orange
        }
    }
    
    private var permissionText: String {
        switch permissionStatus {
        case .authorized, .provisional:
            return "Notifications allowed"
        case .denied:
            return "Notifications denied"
        case .notDetermined:
            return "Not requested yet"
        @unknown default:
            return "Unknown status"
        }
    }
    
    private func checkPermissionStatus() {
        NotificationManager.shared.checkPermissionStatus { status in
            permissionStatus = status
        }
    }
    
    private func requestPermission() {
        NotificationManager.shared.requestPermission { granted in
            checkPermissionStatus()
            if !granted {
                showingPermissionAlert = true
            }
        }
    }
    
    private func ensurePermission() {
        NotificationManager.shared.checkPermissionStatus { status in
            if status == .notDetermined {
                requestPermission()
            } else if status == .denied {
                showingPermissionAlert = true
            }
        }
    }
    
    private func testNotification() {
        // Check permission first
        NotificationManager.shared.checkPermissionStatus { status in
            print("📱 Permission Status: \(status.rawValue)")
            
            if status == .authorized || status == .provisional {
                NotificationManager.shared.sendTransactionNotification(
                    amount: -25.50,
                    category: "Test",
                    type: "expense"
                )
                HapticManager.shared.success()
                print("✅ Test notification sent! Background the app to see it.")
            } else if status == .notDetermined {
                NotificationManager.shared.requestPermission { granted in
                    if granted {
                        NotificationManager.shared.sendTransactionNotification(
                            amount: -25.50,
                            category: "Test",
                            type: "expense"
                        )
                        HapticManager.shared.success()
                        print("✅ Permission granted and notification sent!")
                    } else {
                        print("❌ Permission denied!")
                    }
                }
            } else {
                print("❌ Notifications are DENIED. Go to Settings → FinanceTracker → Notifications")
            }
        }
    }
}

// MARK: - Privacy & Security
struct PrivacySettingsView: View {
    @State private var faceIDEnabled = true
    @State private var analyticsEnabled = true
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Security")) {
                Toggle("Use Face ID", isOn: $faceIDEnabled)
                NavigationLink("Two-Factor Authentication") {
                    Text("2FA Setup")
                        .navigationTitle("2FA")
                }
            }
            
            Section(header: Text("Data")) {
                Toggle("Share Analytics", isOn: $analyticsEnabled)
                NavigationLink("Data & Privacy Info") {
                    Text("Privacy Policy Content")
                        .navigationTitle("Privacy Policy")
                }
            }
        }
        .navigationTitle("Privacy & Security")
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Help Center
struct HelpCenterView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List {
            Section(header: Text("FAQ")) {
                NavigationLink("How to add a transaction?") {
                    Text("Tap the + button on the home screen.")
                        .padding()
                        .navigationTitle("Adding Transactions")
                }
                NavigationLink("How to set a budget?") {
                    Text("Go to the Wallet tab and tap + next to Budgets.")
                        .padding()
                        .navigationTitle("Setting Budgets")
                }
                NavigationLink("Exporting data") {
                    Text("Data export is coming soon.")
                        .padding()
                        .navigationTitle("Export Data")
                }
            }
            
            Section(header: Text("Contact")) {
                Button("Contact Support") {
                    // Email support action
                }
                Button("Report a Bug") {
                    // Report bug action
                }
            }
        }
        .navigationTitle("Help Center")
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }
}

// MARK: - About Us
struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.doc.horizontal.fill")
                .font(.system(size: 80))
                .foregroundColor(.primary)
                .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text("Finance Tracker")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            List {
                Section {
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("David Wu")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Website")
                        Spacer()
                        Text("example.com")
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(Color(UIColor.secondarySystemBackground))
                
                Section {
                    Button("Rate App") { }
                    Button("Terms of Service") { }
                    Button("Privacy Policy") { }
                }
                .listRowBackground(Color(UIColor.secondarySystemBackground))
            }
            .scrollContentBackground(.hidden)
        }
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .navigationTitle("About Us")
    }
}
