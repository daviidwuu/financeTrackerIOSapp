import Foundation
import UserNotifications
import FirebaseFirestore
import BackgroundTasks

import FirebaseMessaging

class NotificationManager: NSObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = NotificationManager()
    static let dailySummaryTaskID = "com.davidwu.financetracker.dailySummary"
    static let inactivityTaskID = "com.davidwu.financetracker.inactivityCheck"
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
    }
    
    private func setupNotificationCategories() {
        // Transaction Actions
        let viewAction = UNNotificationAction(identifier: "VIEW_ACTION", title: "View Details", options: .foreground)
        let transactionCategory = UNNotificationCategory(identifier: "TRANSACTION", actions: [viewAction], intentIdentifiers: [], options: .customDismissAction)
        
        // Split Actions
        let remindAction = UNNotificationAction(identifier: "REMIND_ACTION", title: "Remind Friend", options: .foreground)
        let splitCategory = UNNotificationCategory(identifier: "SPLIT", actions: [remindAction], intentIdentifiers: [], options: .customDismissAction)
        
        // Daily Summary Actions
        let analyticsAction = UNNotificationAction(identifier: "ANALYTICS_ACTION", title: "View Analytics", options: .foreground)
        let summaryCategory = UNNotificationCategory(identifier: "DAILY_SUMMARY", actions: [analyticsAction], intentIdentifiers: [], options: .customDismissAction)
        
        UNUserNotificationCenter.current().setNotificationCategories([transactionCategory, splitCategory, summaryCategory])
    }
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.dailySummaryTaskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleDailySummaryTask(task: task)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.inactivityTaskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleInactivityTask(task: task)
        }
    }
    
    // MARK: - Permission Management
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    DebugLogger.log("Notification permission error: \(error)")
                }
                completion(granted)
            }
        }
    }
    
    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    // MARK: - Transaction Notifications
    
    func sendTransactionNotification(amount: Double, category: String, type: String, originalAmount: Double? = nil, currencyCode: String? = nil) {
        // Auto-request permission if needed
        checkPermissionStatus { status in
            if status == .notDetermined {
                self.requestPermission { granted in
                    if granted {
                        self.sendNotification(amount: amount, category: category, type: type, originalAmount: originalAmount, currencyCode: currencyCode)
                    } else {
                        DebugLogger.log("❌ Notification permission denied")
                    }
                }
            } else if status == .authorized || status == .provisional {
                self.sendNotification(amount: amount, category: category, type: type, originalAmount: originalAmount, currencyCode: currencyCode)
            } else {
                DebugLogger.log("❌ Notifications not authorized. Status: \(status.rawValue)")
            }
        }
    }
    
    private func sendNotification(amount: Double, category: String, type: String, originalAmount: Double? = nil, currencyCode: String? = nil) {
        // Check if transaction notifications are enabled (optional for now)
        let isEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled_transactions")
        
        // Send anyway for debugging - remove this line in production
         guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        
        // Format: "You have spent $6 (HKD$12) on (Category)"
        var bodyString = ""
        if type == "income" {
            content.title = "Income Received"
            bodyString = "You received $\(Int(abs(amount)))"
        } else {
            content.title = "Expense Added"
            bodyString = "You have spent $\(Int(abs(amount)))"
        }
        
        // Add Travel Currency info if available
        if let original = originalAmount, let code = currencyCode {
             bodyString += " (\(code)$\(Int(abs(original))))"
        }
        
        if type == "income" {
            bodyString += " from \(category)"
        } else {
            bodyString += " on \(category)"
        }
        
        content.body = bodyString
        
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "TRANSACTION"
        
        DebugLogger.log("🔔 Scheduling notification: \(content.title) - \(content.body)")
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DebugLogger.log("❌ Failed to send transaction notification: \(error)")
            } else {
                DebugLogger.log("✅ Notification scheduled successfully!")
            }
        }
    }
    
    // MARK: - Budget Notifications
    
    func sendBudgetWarning(category: String, percentUsed: Int, remaining: Double) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_budgets") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Budget Alert"
        content.body = "\(category): \(percentUsed)% spent! $\(Int(remaining)) remaining"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DebugLogger.log("Failed to send budget warning: \(error)")
            }
        }
    }
    
    // MARK: - Daily Summary
    
    func scheduleDailySummary() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_dailySummary") else { return }
        
        let request = BGAppRefreshTaskRequest(identifier: Self.dailySummaryTaskID)
        request.earliestBeginDate = getNextScheduledTime()
        
        do {
            try BGTaskScheduler.shared.submit(request)
            DebugLogger.log("✅ Scheduled background task for \(request.earliestBeginDate?.description ?? "unknown")")
        } catch {
            DebugLogger.log("❌ Could not schedule background task: \(error)")
        }
    }
    
    private func getNextScheduledTime() -> Date {
        let storedSeconds = UserDefaults.standard.double(forKey: "dailySummaryTime")
        // Default to 9 PM (21 * 3600 = 75600) if not set or 0
        let totalSeconds = storedSeconds > 0 ? Int(storedSeconds) : 75600
        
        let hour = totalSeconds / 3600
        let minute = (totalSeconds % 3600) / 60
        
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        
        guard let scheduledDate = calendar.date(from: components) else { return now.addingTimeInterval(3600) }
        
        if scheduledDate < now {
            return calendar.date(byAdding: .day, value: 1, to: scheduledDate)!
        }
        return scheduledDate
    }
    
    func cancelDailySummary() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.dailySummaryTaskID)
    }
    
    private func handleDailySummaryTask(task: BGAppRefreshTask) {
        // Schedule the next one immediately
        scheduleDailySummary()
        
        task.expirationHandler = {
            // Cancel operations if system kills us
        }
        
        let userId = AppState.shared.currentUserId
        guard !userId.isEmpty else {
            task.setTaskCompleted(success: false)
            return
        }
        
        // Fetch today's transactions
        let db = Firestore.firestore()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        db.collection("users").document(userId).collection("transactions")
            .whereField("date", isGreaterThanOrEqualTo: startOfDay)
            .whereField("date", isLessThan: endOfDay)
            .getDocuments { snapshot, error in
                if let error = error {
                    DebugLogger.log("Error fetching daily transactions: \(error)")
                    task.setTaskCompleted(success: false)
                    return
                }
                
                let documents = snapshot?.documents ?? []
                let expenses = documents.compactMap { doc -> Double? in
                    let data = doc.data()
                    let amount = data["amount"] as? Double ?? 0
                    return amount < 0 ? abs(amount) : nil
                }
                
                let totalSpent = expenses.reduce(0, +)
                let count = expenses.count
                
                if count > 0 {
                    let content = UNMutableNotificationContent()
                    content.title = "Daily Summary"
                    content.body = "You spent $\(Int(totalSpent)) across \(count) transactions today."
                    content.sound = .default
                    content.userInfo = ["date": Date().timeIntervalSince1970]
                    content.categoryIdentifier = "DAILY_SUMMARY"
                    
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // Deliver immediately
                    UNUserNotificationCenter.current().add(request)
                }
                
                // Check for Split Reminders before completing the task
                self.checkSplitBillReminders {
                    task.setTaskCompleted(success: true)
                }
            }
    }
    
    // MARK: - Split Reminders
    
    func checkSplitBillReminders(completion: @escaping () -> Void = {}) {
         guard UserDefaults.standard.bool(forKey: "notificationsEnabled_unpaidSplits") else {
             completion()
             return
         }
         
         let userId = AppState.shared.currentUserId
         guard !userId.isEmpty else {
             completion()
             return
         }
         
         let db = Firestore.firestore()
         let sixtyDaysAgo = Date().addingTimeInterval(-60 * 24 * 3600)
         
         db.collection("users").document(userId).collection("transactions")
             .whereField("date", isGreaterThan: sixtyDaysAgo)
             .getDocuments { [weak self] snapshot, error in
                 guard let self = self else { 
                     completion()
                     return 
                 }
                 
                 if let error = error {
                     DebugLogger.log("Error checking splits: \(error.localizedDescription)")
                     completion()
                     return
                 }
                 
                 guard let snapshot = snapshot else {
                     completion()
                     return
                 }
                 
                 let documents = snapshot.documents
                 
                 Task { @MainActor in
                     var unpaidCount = 0
                     var totalOwed = 0.0
                     
                     for doc in documents {
                         do {
                            let transaction = try doc.data(as: FirestoreModels.Transaction.self)
                            if let splits = transaction.splits, !splits.isEmpty {
                                let unpaidSplits = splits.filter { !$0.isPaid }
                                if !unpaidSplits.isEmpty {
                                    let timeDiff = Date().timeIntervalSince(transaction.date)
                                    let daysDiff = Int(timeDiff / (24 * 3600))
                                    
                                    if daysDiff >= 1 && daysDiff % 2 != 0 {
                                        unpaidCount += unpaidSplits.count
                                        totalOwed += unpaidSplits.reduce(0.0) { $0 + $1.amount }
                                    }
                                }
                            }
                         } catch {
                            continue
                         }
                     }
                     
                     if unpaidCount > 0 {
                         self.sendSplitReminder(count: unpaidCount, total: totalOwed)
                     }
                     
                     completion()
                 }
             }
    }
    
    private func sendSplitReminder(count: Int, total: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Unpaid Splits Reminder"
        content.body = "You have \(count) unpaid split\(count > 1 ? "s" : "") totaling $\(Int(total)). Check if friends have paid you back!"
        content.sound = .default
        content.categoryIdentifier = "SPLIT"
        
        let request = UNNotificationRequest(identifier: "split-reminder-\(Date().timeIntervalSince1970)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Weekly Report
    
    func scheduleWeeklyReport() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_weeklyReport") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Report"
        content.body = "Your weekly financial report is ready!"
        content.sound = .default
        
        // Schedule for Sunday at 8 PM
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-report", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DebugLogger.log("Failed to schedule weekly report: \(error)")
            }
        }
    }
    
    func cancelWeeklyReport() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly-report"])
    }
    
    // MARK: - Inactivity Check
    
    func scheduleInactivityCheck() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_inactivity") else { return }
        
        let request = BGAppRefreshTaskRequest(identifier: Self.inactivityTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600) // 4 hours from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            DebugLogger.log("✅ Scheduled inactivity check")
        } catch {
            DebugLogger.log("❌ Could not schedule inactivity task: \(error)")
        }
    }
    
    func cancelInactivityCheck() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.inactivityTaskID)
    }
    
    private func handleInactivityTask(task: BGAppRefreshTask) {
        // Schedule next check
        scheduleInactivityCheck()
        
        task.expirationHandler = {
            // Cleanup
        }
        
        // Time Window Check: 10 AM - 8 PM
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 10 && hour < 20 else {
            task.setTaskCompleted(success: true)
            return
        }
        
        let userId = AppState.shared.currentUserId
        guard !userId.isEmpty else {
            task.setTaskCompleted(success: false)
            return
        }
        
        // Check for transactions in the last 4 hours
        let db = Firestore.firestore()
        let fourHoursAgo = Date().addingTimeInterval(-4 * 3600)
        
        db.collection("users").document(userId).collection("transactions")
            .whereField("createdAt", isGreaterThan: fourHoursAgo)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    DebugLogger.log("Error checking inactivity: \(error)")
                    task.setTaskCompleted(success: false)
                    return
                }
                
                // If no documents found, user hasn't logged anything
                if snapshot?.documents.isEmpty ?? true {
                    let userName = AppState.shared.userName
                    let message = NotificationContent.getMessage(for: .inactivity, userName: userName)
                    
                    let content = UNMutableNotificationContent()
                    content.title = message.title
                    content.body = message.body
                    content.sound = .default
                    
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
                
                task.setTaskCompleted(success: true)
            }
    }
    
    // MARK: - End of Day Check
    
    func scheduleEODCheck() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_eod") else { return }
        
        var dateComponents = DateComponents()
        dateComponents.hour = 22 // 10 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let userName = AppState.shared.userName
        let message = NotificationContent.getMessage(for: .endOfDay, userName: userName)
        
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "eod-check", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DebugLogger.log("Failed to schedule EOD check: \(error)")
            }
        }
    }
    
    func cancelEODCheck() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["eod-check"])
    }
    
    // MARK: - Motivational Tips
    
    func scheduleMotivationalTips() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_tips") else { return }
        
        // Schedule for 7am, 10am, 1pm, 4pm, 7pm
        let hours = [7, 10, 13, 16, 19]
        let userName = AppState.shared.userName
        
        for hour in hours {
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            // Note: In a real app, you might want to dynamically randomize this content
            // For now, we schedule it. To make it dynamic, we'd use a background task to schedule local notifs nearby,
            // or just rely on the static content generated at schedule time (which limits variety until app re-opens).
            // Better approach for variety: Use Background Task to schedule the *next* tip.
            // But simplifying here: We will just schedule them.
            // Wait, if we schedule them now, the message is fixed.
            // To make it dynamic, let's use the Background Task approach or just accept fixed messages until next launch.
            // Let's accept fixed messages for MVP simplification, but re-schedule on app launch.
            
            let message = NotificationContent.getMessage(for: .motivational, userName: userName)
            
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: "tip-\(hour)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func cancelMotivationalTips() {
        let identifiers = [7, 10, 13, 16, 19].map { "tip-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Clear Badges
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    

    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner and play sound even when app is in foreground
        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let categoryId = response.notification.request.content.categoryIdentifier
        
        // Handle Travel Notification
        if let type = userInfo["type"] as? String, type == "travel_update" {
             DispatchQueue.main.async {
                 AppState.shared.showProfile = true
                 
                 // Delay slightly to ensure Profile View is mounted before triggering navigation
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                     AppState.shared.shouldOpenCurrencySettings = true
                 }
             }
        
        // --- 1. Daily Summary (Deep Link) ---
        } else if categoryId == "DAILY_SUMMARY" || response.actionIdentifier == "ANALYTICS_ACTION" {
            if let timestamp = userInfo["date"] as? TimeInterval {
                let date = Date(timeIntervalSince1970: timestamp)
                DispatchQueue.main.async {
                    AppState.shared.dailySummaryDate = date
                    AppState.shared.showDailySummary = true
                }
            } else {
                 DispatchQueue.main.async {
                     // Default to today if no date provided
                     AppState.shared.dailySummaryDate = Date()
                     AppState.shared.showDailySummary = true
                 }
            }
        
        // --- 2. Transactions (View Details) ---
        } else if categoryId == "TRANSACTION" || response.actionIdentifier == "VIEW_ACTION" {
            DispatchQueue.main.async {
                // Ensure we are on the Home Dashboard
                AppState.shared.selectedTab = 0
                // We could potentially open a detail view if a Transaction ID was passed, 
                // but for now, just taking them to the list is good.
                // Or maybe show the "All Transactions" sheet
                 // AppState.shared.showDailySummary = true // Reusing 'AllTransactionsView' which is what Daily Summary uses
            }
            
        // --- 3. Split Reminders (Friends/Profile) ---
        } else if categoryId == "SPLIT" || response.actionIdentifier == "REMIND_ACTION" {
            DispatchQueue.main.async {
                // Navigate to the Profile where Friends are usually located
                AppState.shared.showProfile = true
            }
        
        // --- 4. Budget Alerts (Wallet Tab) ---
        } else if response.notification.request.content.title == "Budget Alert" {
             DispatchQueue.main.async {
                 // Switch to Wallet Tab (Index 1)
                 AppState.shared.selectedTab = 1
             }
             
        // --- 5. Inactivity Check (Prompt to Add Transaction) ---
        } else if categoryId == "INACTIVITY" || response.actionIdentifier == "LOG_ACTION" { // Assuming we add this category later
             DispatchQueue.main.async {
                 AppState.shared.selectedTab = 0
                 // There isn't a direct "showAddTransaction" in AppState, 
                 // but we can add one or use a URL scheme if ContentView listens for it.
                 // For now, just going to Home is sufficient prompt.
                 // Actually, let's use the URL scheme we saw in ContentView!
                 if let url = URL(string: "financetracker://add-transaction") {
                     UIApplication.shared.open(url)
                 }
             }
             
        // --- 6. Weekly Report (Wallet or Summary) ---
        } else if response.notification.request.content.title == "Weekly Report" {
             DispatchQueue.main.async {
                 AppState.shared.showWeeklyReport = true
             }
             
        // --- 7. Goal Milestones (Wallet Tab) ---
        } else if response.notification.request.content.title.contains("Goal") {
             DispatchQueue.main.async {
                 AppState.shared.selectedTab = 1
             }
        }

        completionHandler()
    }

    // MARK: - MessagingDelegate
    
    // MARK: - MessagingDelegate
    
    private var cachedFCMToken: String?
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        DebugLogger.log("FCM Token: \(token)")
        self.cachedFCMToken = token
        
        // Save to User Profile if logged in
        syncTokenWithServer()
    }
    
    func syncTokenWithServer() {
        guard let token = cachedFCMToken ?? Messaging.messaging().fcmToken else { return }
        let userId = AppState.shared.currentUserId
        
        if !userId.isEmpty {
             Task {
                 try? await FirebaseManager.shared.updateFCMToken(userId: userId, token: token)
                 DebugLogger.log("✅ FCM Token synced for user: \(userId)")
             }
        }
    }
}
