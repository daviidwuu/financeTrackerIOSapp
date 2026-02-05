import SwiftUI

// MARK: - Account Settings
struct AccountSettingsView: View {
    @EnvironmentObject var appState: AppState
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
        Form {
            Section(header: Text("Profile Information")) {
                TextField("Name", text: $name)
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: username) { _, newValue in
                            checkUsername(newValue)
                        }
                    
                    if isCheckingUsername {
                        Text("Checking availability...")
                             .font(.caption)
                             .foregroundColor(.secondary)
                    } else if let msg = usernameMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(usernameAvailable ? .green : .red)
                    }
                }
                
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
                .disabled(isLoading || name.isEmpty || email.isEmpty || username.isEmpty || !usernameAvailable || (name == appState.userName && email == appState.userEmail && username == initialUsername))
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
        .background(Color.listBackground)
        .scrollContentBackground(.hidden)
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
                    self.usernameMessage = isAvailable ? "Username available" : "Username taken"
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
                if name != appState.userName {
                    try await FirebaseManager.shared.updateUserProfile(userId: appState.currentUserId, data: ["name": name])
                    await MainActor.run { appState.userName = name }
                }
                
                if username != initialUsername {
                    try await FirebaseManager.shared.updateUserProfile(userId: appState.currentUserId, data: ["username": username])
                    await MainActor.run { 
                        appState.currentUserUsername = username 
                        initialUsername = username
                    }
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
    @AppStorage("userTheme") private var userTheme: String = "system"
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Display")) {
            Section(header: Text("Display")) {
                Picker("Theme", selection: $userTheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.menu)
            }
            }
        }
        .navigationTitle("Appearance")
        .background(Color.listBackground)
        .scrollContentBackground(.hidden)
    }
}


// MARK: - Notifications
struct NotificationsSettingsView: View {
    @AppStorage("notificationsEnabled_transactions") private var transactionNotifs = false
    @AppStorage("notificationsEnabled_budgets") private var budgetNotifs = false
    @AppStorage("notificationsEnabled_dailySummary") private var dailySummary = false
    @AppStorage("notificationsEnabled_weeklyReport") private var weeklyReport = false
    @AppStorage("notificationsEnabled_inactivity") private var inactivityCheck = false
    @AppStorage("notificationsEnabled_eod") private var eodCheck = false
    @AppStorage("notificationsEnabled_tips") private var motivationalTips = false
    @AppStorage("notificationsEnabled_unpaidSplits") private var unpaidSplitReminders = false
    @AppStorage("notificationsEnabled_goals") private var goalMilestones = false
    
    // New Settings
    @AppStorage("budgetAlertThreshold") private var budgetAlertThreshold: Double = 0.8
    @AppStorage("dailySummaryTime") private var dailySummaryTime: Double = 75600 // 21:00 default (21 * 3600)
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingPermissionAlert = false
    @State private var summaryDate: Date = Date()
    
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
                        Text("Send Test Notification")
                        Spacer()
                        Image(systemName: "paperplane.fill")
                    }
                }
            }
            
            // Transaction Alerts
            Section(header: Text("Transaction Alerts"), footer: Text("Get notified when you add or edit transactions")) {
                Toggle("Transaction Notifications", isOn: $transactionNotifs)
                    .onChange(of: transactionNotifs) { _, newValue in
                        if newValue { ensurePermission() }
                    }
            }
            
            // Budget Alerts
            Section(header: Text("Budget Alerts"), footer: Text("Get warned when you reach a % of your budget")) {
                Toggle("Budget Warnings", isOn: $budgetNotifs)
                    .onChange(of: budgetNotifs) { _, newValue in
                        if newValue { ensurePermission() }
                    }
                
                if budgetNotifs {
                    Picker("Alert Threshold", selection: $budgetAlertThreshold) {
                        Text("50%").tag(0.5)
                        Text("80%").tag(0.8)
                        Text("90%").tag(0.9)
                        Text("100%").tag(1.0)
                    }
                }
            }
            
            // Split Bill Reminders
            Section(header: Text("Split Reminders"), footer: Text("Get reminded about unpaid splits >24h old, every 2 days")) {
               Toggle("Unpaid Split Reminders", isOn: $unpaidSplitReminders)
                   .onChange(of: unpaidSplitReminders) { _, newValue in
                       if newValue { ensurePermission() }
                   }
            }
            
            // Scheduled Reports
            Section(header: Text("Scheduled Reports")) {
                Toggle("Daily Summary", isOn: $dailySummary)
                    .onChange(of: dailySummary) { _, newValue in
                        if newValue {
                            ensurePermission()
                            updateDailySummarySchedule()
                        } else {
                            NotificationManager.shared.cancelDailySummary()
                        }
                    }
                
                if dailySummary {
                    DatePicker("Time", selection: $summaryDate, displayedComponents: .hourAndMinute)
                        .onChange(of: summaryDate) { _, newDate in
                            // Save seconds from midnight
                            let calendar = Calendar.current
                            let components = calendar.dateComponents([.hour, .minute], from: newDate)
                            let seconds = (Double(components.hour ?? 21) * 3600) + (Double(components.minute ?? 0) * 60)
                            dailySummaryTime = seconds
                            updateDailySummarySchedule()
                        }
                }
                
                Toggle("Weekly Report (Sunday 8 PM)", isOn: $weeklyReport)
                    .onChange(of: weeklyReport) { _, newValue in
                        if newValue {
                            ensurePermission()
                            NotificationManager.shared.scheduleWeeklyReport()
                        } else {
                            NotificationManager.shared.cancelWeeklyReport()
                        }
                    }
            }
            
            // Engagement & Tips
            Section(header: Text("Engagement")) {
                Toggle("Inactivity Reminders (Every 4h)", isOn: $inactivityCheck)
                    .onChange(of: inactivityCheck) { _, newValue in
                        if newValue {
                            ensurePermission()
                            NotificationManager.shared.scheduleInactivityCheck()
                        } else {
                            NotificationManager.shared.cancelInactivityCheck()
                        }
                    }
                
                Toggle("End of Day Check (10 PM)", isOn: $eodCheck)
                    .onChange(of: eodCheck) { _, newValue in
                        if newValue {
                            ensurePermission()
                            NotificationManager.shared.scheduleEODCheck()
                        } else {
                            NotificationManager.shared.cancelEODCheck()
                        }
                    }
                
                Toggle("Motivational Tips (Every 3h)", isOn: $motivationalTips)
                    .onChange(of: motivationalTips) { _, newValue in
                        if newValue {
                            ensurePermission()
                            NotificationManager.shared.scheduleMotivationalTips()
                        } else {
                            NotificationManager.shared.cancelMotivationalTips()
                        }
                    }
                
                Toggle("Goal Milestones", isOn: $goalMilestones)
                    .onChange(of: goalMilestones) { _, newValue in
                        if newValue { ensurePermission() }
                    }
            }
        }
        .navigationTitle("Notifications")
        .background(Color.listBackground)
        .scrollContentBackground(.hidden)
        .onAppear {
            checkPermissionStatus()
            // Initialize Summary Date from Stored Time
            let totalSeconds = Int(dailySummaryTime)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = hours
            components.minute = minutes
            if let date = calendar.date(from: components) {
                summaryDate = date
            }
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
    
    private func updateDailySummarySchedule() {
        NotificationManager.shared.scheduleDailySummary()
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
        default:
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
            DebugLogger.log("📱 Permission Status: \(status.rawValue)")
            
            if status == .authorized || status == .provisional {
                NotificationManager.shared.sendTransactionNotification(
                    amount: -25.50,
                    category: "Test",
                    type: "expense"
                )
                HapticManager.shared.success()
                DebugLogger.log("✅ Test notification sent! Background the app to see it.")
            } else if status == .notDetermined {
                NotificationManager.shared.requestPermission { granted in
                    if granted {
                        NotificationManager.shared.sendTransactionNotification(
                            amount: -25.50,
                            category: "Test",
                            type: "expense"
                        )
                        HapticManager.shared.success()
                        DebugLogger.log("✅ Permission granted and notification sent!")
                    } else {
                        DebugLogger.log("❌ Permission denied!")
                    }
                }
            } else {
                DebugLogger.log("❌ Notifications are DENIED. Go to Settings → FinanceTracker → Notifications")
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
        .background(Color.listBackground)
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
        .background(Color.listBackground)
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
                Text("wym")
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
        .background(Color.listBackground)
        .navigationTitle("About Us")
    }
}
