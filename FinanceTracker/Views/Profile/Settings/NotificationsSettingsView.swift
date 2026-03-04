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
        ZStack {
            // Background
            Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)
                    
                    // Permission Status Section
                    MenuSection("System Permission") {
                        MenuControlRow(icon: permissionIcon, iconColor: permissionColor, title: "Notification Access", subtitle: permissionText) {
                            if permissionStatus == .notDetermined || permissionStatus == .denied {
                                Button("Enable") { HapticManager.shared.light(); 
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
                    }
                    
                    // Test Notification Button
                    MenuSection(nil) {
                        Button(action: {
                            HapticManager.shared.light()
                            testNotification()
                        }) {
                            MenuRowView(icon: "paperplane.fill", title: "Send Test Notification", showChevron: false, iconColor: .blue)
                        }
                        .buttonStyle(MenuRowButtonStyle())
                    }
                    
                    // Transaction Alerts
                    MenuSection("Transaction Alerts") {
                        MenuRowView(icon: "arrow.left.arrow.right", title: "New Transactions", showChevron: false, showToggle: $transactionNotifs, iconColor: .green)
                        MenuDivider()
                        MenuRowView(icon: "exclamationmark.triangle.fill", title: "Large Expense Alert", showChevron: false, showToggle: $largeExpenseAlert, iconColor: .orange)
                        
                        if largeExpenseAlert {
                            MenuDivider()
                            MenuControlRow(icon: "dollarsign.circle", iconColor: .red, title: "Threshold") {
                                TextField("Amount", value: $largeExpenseThreshold, format: .currency(code: CurrencyManager.shared.mainCurrency))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color(UIColor.tertiarySystemFill))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .onChange(of: transactionNotifs) { _, newValue in
                        HapticManager.shared.light()
                        if newValue { ensurePermission() }
                    }
                    .onChange(of: largeExpenseAlert) { _, newValue in if newValue { ensurePermission() } }
                    
                    // Budget & Bills
                    MenuSection("Budget & Bills") {
                        MenuRowView(icon: "chart.pie.fill", title: "Budget Warnings", showChevron: false, showToggle: $budgetNotifs, iconColor: .indigo)
                        if budgetNotifs {
                            MenuDivider()
                            MenuControlRow(icon: "percent", iconColor: .purple, title: "Alert Threshold") {
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
                        }
                        
                        MenuDivider()
                        MenuRowView(icon: "doc.plaintext.fill", title: "Bill Reminders", showChevron: false, showToggle: $billReminders, iconColor: .blue)
                        MenuDivider()
                        MenuRowView(icon: "person.2.fill", title: "Unpaid Split Reminders", showChevron: false, showToggle: $unpaidSplitReminders, iconColor: .cyan)
                    }
                    .onChange(of: budgetNotifs) { _, newValue in if newValue { ensurePermission() } }
                    .onChange(of: billReminders) { _, newValue in if newValue { ensurePermission() } }
                    .onChange(of: unpaidSplitReminders) { _, newValue in if newValue { ensurePermission() } }
                    
                    // Scheduled Reports
                    MenuSection("Scheduled Reports") {
                        MenuRowView(icon: "sun.max.fill", title: "Daily Summary", showChevron: false, showToggle: $dailySummary, iconColor: .yellow)
                        
                        if dailySummary {
                            MenuDivider()
                            MenuControlRow(icon: "clock.fill", iconColor: .gray, title: "Time") {
                                DatePicker("", selection: $summaryDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                        
                        MenuDivider()
                        MenuRowView(icon: "calendar", title: "Weekly Report (Sunday 8 PM)", showChevron: false, showToggle: $weeklyReport, iconColor: .red)
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
                        MenuRowView(icon: "moon.zzz.fill", title: "Inactivity Reminders", showChevron: false, showToggle: $inactivityCheck, iconColor: .indigo)
                        MenuDivider()
                        MenuRowView(icon: "flame.fill", title: "Streak Warnings", showChevron: false, showToggle: $streakWarnings, iconColor: .orange)
                        MenuDivider()
                        MenuRowView(icon: "moon.fill", title: "End of Day Check", showChevron: false, showToggle: $eodCheck, iconColor: .blue)
                        MenuDivider()
                        MenuRowView(icon: "lightbulb.fill", title: "Motivational Tips", showChevron: false, showToggle: $motivationalTips, iconColor: .yellow)
                        MenuDivider()
                        MenuRowView(icon: "flag.checkered.2.crossed", title: "Goal Milestones", showChevron: false, showToggle: $goalMilestones, iconColor: .green)
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
        }
        .overlayHeader(.navigation(title: "Notifications", onBack: { dismiss() }))
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
            Button("Cancel", role: .cancel) { HapticManager.shared.light(); }
            Button("Settings") { HapticManager.shared.light(); 
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
            return "bell.fill"
        case .denied:
            return "bell.slash.fill"
        default:
            return "bell.badge.fill"
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
