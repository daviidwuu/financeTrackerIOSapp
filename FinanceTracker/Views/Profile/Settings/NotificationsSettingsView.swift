import SwiftUI
import WidgetKit

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
    @Environment(\.dismiss) var dismiss
    
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingPermissionAlert = false
    @State private var summaryDate: Date = Date()
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)
                    
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
                                .cornerRadius(AppRadius.small)
                            }
                        }
                        .padding(AppSpacing.element)
                    }
                    .padding(.top, 0)
                    
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
                            .padding(AppSpacing.element)
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
                    .onChange(of: transactionNotifs) { _, newValue in
                        HapticManager.shared.light()
                        if newValue { ensurePermission() }
                    }
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
                            .onChange(of: budgetAlertThreshold) { _, _ in
                                HapticManager.shared.light()
                            }
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
                
                Text("Notifications")
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
                DebugLogger.log("❌ Notifications are DENIED. Go to Settings → wym → Notifications")
            }
        }
    }
}

// MARK: - Privacy & Security
