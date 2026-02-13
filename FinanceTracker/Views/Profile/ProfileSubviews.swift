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
        ScrollView {
            VStack(spacing: 24) {
                // Profile Information Section
                MenuSection("Profile Information") {
                    MenuInputRow(title: "Name", text: $name)
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
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // Actions
                MenuSection {
                    Button(action: updateProfile) {
                        Text("Update Profile")
                    }
                    .buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
                    .disabled(isLoading || name.isEmpty || email.isEmpty || username.isEmpty || !usernameAvailable || (name == appState.userName && email == appState.userEmail && username == initialUsername))
                    .padding(16)
                }
                
                // Security
                MenuSection("Security") {
                     Button(action: { sendPasswordReset() }) {
                         MenuRowView(icon: "lock.rotation", title: "Reset Password", showChevron: true)
                     }
                     .buttonStyle(.plain)
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
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.inline)
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
        ScrollView {
            VStack(spacing: 24) {
                MenuSection("Display") {
                    HStack {
                        Text("Theme")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Picker("Theme", selection: $userTheme) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .contentShape(Rectangle())
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
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
    @AppStorage("notificationsEnabled_billReminders") private var billReminders = false
    @AppStorage("notificationsEnabled_streaks") private var streakWarnings = false
    @AppStorage("notificationsEnabled_largeExpense") private var largeExpenseAlert = false
    
    @AppStorage("budgetAlertThreshold") private var budgetAlertThreshold: Double = 0.8
    @AppStorage("largeExpenseThreshold") private var largeExpenseThreshold: Double = 100.0
    @AppStorage("dailySummaryTime") private var dailySummaryTime: Double = 75600 // 21:00 default (21 * 3600)
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingPermissionAlert = false
    @State private var summaryDate: Date = Date()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Permission Status Section
                MenuSection {
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
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    }
                    .padding(16)
                }
                
                // Test Notification Button
                MenuSection {
                    Button(action: {
                        testNotification()
                    }) {
                        HStack {
                            Image(systemName: "bell.badge")
                            Text("Send Test Notification")
                            Spacer()
                            Image(systemName: "paperplane.fill")
                        }
                        .foregroundColor(.blue)
                        .padding(16)
                    }
                }
                
                // Transaction Alerts
                MenuSection("Transaction Alerts") {
                    MenuRowView(title: "New Transactions", showChevron: false, showToggle: $transactionNotifs)
                    MenuDivider()
                    MenuRowView(title: "Large Expense Alert", showChevron: false, showToggle: $largeExpenseAlert)
                    
                    if largeExpenseAlert {
                        MenuDivider()
                        HStack {
                            Text("Threshold")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            TextField("Amount", value: $largeExpenseThreshold, format: .currency(code: CurrencyManager.shared.mainCurrency))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(6)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                    }
                }
                .onChange(of: transactionNotifs) { _, newValue in if newValue { ensurePermission() } }
                .onChange(of: largeExpenseAlert) { _, newValue in if newValue { ensurePermission() } }
                
                // Budget & Bills
                MenuSection("Budget & Bills") {
                    MenuRowView(title: "Budget Warnings", showChevron: false, showToggle: $budgetNotifs)
                    if budgetNotifs {
                        MenuDivider()
                        HStack {
                            Text("Alert Threshold")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            Picker("Threshold", selection: $budgetAlertThreshold) {
                                Text("50%").tag(0.5)
                                Text("80%").tag(0.8)
                                Text("90%").tag(0.9)
                                Text("100%").tag(1.0)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(UIColor.secondarySystemBackground))
                    }
                    
                    MenuDivider()
                    MenuRowView(title: "Bill Reminders", showChevron: false, showToggle: $billReminders)
                    MenuDivider()
                    MenuRowView(title: "Unpaid Split Reminders", showChevron: false, showToggle: $unpaidSplitReminders)
                }
                .onChange(of: budgetNotifs) { _, newValue in if newValue { ensurePermission() } }
                .onChange(of: billReminders) { _, newValue in if newValue { ensurePermission() } }
                .onChange(of: unpaidSplitReminders) { _, newValue in if newValue { ensurePermission() } }
                
                // Scheduled Reports
                MenuSection("Scheduled Reports") {
                    MenuRowView(title: "Daily Summary", showChevron: false, showToggle: $dailySummary)
                    
                    if dailySummary {
                        MenuDivider()
                        HStack {
                            Text("Time")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            DatePicker("", selection: $summaryDate, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color(UIColor.secondarySystemBackground))
                    }
                    
                    MenuDivider()
                    MenuRowView(title: "Weekly Report (Sunday 8 PM)", showChevron: false, showToggle: $weeklyReport)
                }
                .onChange(of: dailySummary) { _, newValue in
                    if newValue {
                        ensurePermission()
                        updateDailySummarySchedule()
                    } else {
                        NotificationManager.shared.cancelDailySummary()
                    }
                }
                .onChange(of: summaryDate) { _, newDate in
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.hour, .minute], from: newDate)
                    let seconds = (Double(components.hour ?? 21) * 3600) + (Double(components.minute ?? 0) * 60)
                    dailySummaryTime = seconds
                    updateDailySummarySchedule()
                }
                .onChange(of: weeklyReport) { _, newValue in
                    if newValue {
                        ensurePermission()
                        NotificationManager.shared.scheduleWeeklyReport()
                    } else {
                        NotificationManager.shared.cancelWeeklyReport()
                    }
                }
                
                // Engagement & Tips
                MenuSection("Engagement") {
                    MenuRowView(title: "Inactivity Reminders", showChevron: false, showToggle: $inactivityCheck)
                    MenuDivider()
                    MenuRowView(title: "Streak Warnings", showChevron: false, showToggle: $streakWarnings)
                    MenuDivider()
                    MenuRowView(title: "End of Day Check", showChevron: false, showToggle: $eodCheck)
                    MenuDivider()
                    MenuRowView(title: "Motivational Tips", showChevron: false, showToggle: $motivationalTips)
                    MenuDivider()
                    MenuRowView(title: "Goal Milestones", showChevron: false, showToggle: $goalMilestones)
                }
                .onChange(of: inactivityCheck) { _, newValue in
                     if newValue { ensurePermission(); NotificationManager.shared.scheduleInactivityCheck() }
                     else { NotificationManager.shared.cancelInactivityCheck() }
                }
                .onChange(of: streakWarnings) { _, newValue in
                    if newValue { ensurePermission() }
                    // Streak warnings are part of inactivity check logic currently
                }
                .onChange(of: eodCheck) { _, newValue in
                    if newValue { ensurePermission(); NotificationManager.shared.scheduleEODCheck() }
                    else { NotificationManager.shared.cancelEODCheck() }
                }
                .onChange(of: motivationalTips) { _, newValue in
                    if newValue { ensurePermission(); NotificationManager.shared.scheduleMotivationalTips() }
                    else { NotificationManager.shared.cancelMotivationalTips() }
                }
                .onChange(of: goalMilestones) { _, newValue in
                    if newValue { ensurePermission() }
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
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
        ScrollView {
            VStack(spacing: 24) {
                MenuSection("Security") {
                    MenuRowView(icon: "faceid", title: "Use Face ID", showChevron: false, showToggle: $faceIDEnabled)
                    MenuDivider()
                    NavigationLink {
                        Text("2FA Setup")
                            .navigationTitle("2FA")
                    } label: {
                        MenuRowView(icon: "lock.shield", title: "Two-Factor Authentication")
                    }
                    .buttonStyle(.plain)
                }
                
                MenuSection("Data") {
                    MenuRowView(title: "Share Analytics", showChevron: false, showToggle: $analyticsEnabled)
                    MenuDivider()
                    NavigationLink {
                        Text("Privacy Policy Content")
                            .navigationTitle("Privacy Policy")
                    } label: {
                        MenuRowView(icon: "hand.raised", title: "Data & Privacy Info")
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Help Center
struct HelpCenterView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                MenuSection("FAQ") {
                    NavigationLink {
                        Text("Tap the + button on the home screen.")
                            .padding()
                            .navigationTitle("Adding Transactions")
                    } label: {
                        MenuRowView(icon: "plus.circle", title: "How to add a transaction?")
                    }
                    .buttonStyle(.plain)
                    
                    MenuDivider()
                    
                    NavigationLink {
                        Text("Go to the Wallet tab and tap + next to Budgets.")
                            .padding()
                            .navigationTitle("Setting Budgets")
                    } label: {
                        MenuRowView(icon: "chart.pie", title: "How to set a budget?")
                    }
                    .buttonStyle(.plain)
                    
                    MenuDivider()
                    
                    NavigationLink {
                        Text("Data export is coming soon.")
                            .padding()
                            .navigationTitle("Export Data")
                    } label: {
                        MenuRowView(icon: "square.and.arrow.up", title: "Exporting data")
                    }
                    .buttonStyle(.plain)
                }
                
                MenuSection("Contact") {
                    Button(action: { }) {
                        MenuRowView(icon: "envelope", title: "Contact Support")
                    }
                    .buttonStyle(.plain)
                    
                    MenuDivider()
                    
                    Button(action: { }) {
                        MenuRowView(icon: "ant", title: "Report a Bug")
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About Us
struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                    
                    Text("FinanceTracker")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                
                MenuSection {
                    HStack {
                        Text("Developer")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("David Wu")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    
                    MenuDivider()
                    
                    HStack {
                        Text("Website")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("example.com")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                }
                
                MenuSection {
                    Button(action: {}) {
                        MenuRowView(title: "Rate App", showChevron: true)
                    }
                    .buttonStyle(.plain)
                    
                    MenuDivider()
                    
                    Button(action: {}) {
                        MenuRowView(title: "Terms of Service", showChevron: true)
                    }
                    .buttonStyle(.plain)
                    
                    MenuDivider()
                    
                    Button(action: {}) {
                        MenuRowView(title: "Privacy Policy", showChevron: true)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.top, 10)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("About Us")
        .navigationBarTitleDisplayMode(.inline)
    }
}


