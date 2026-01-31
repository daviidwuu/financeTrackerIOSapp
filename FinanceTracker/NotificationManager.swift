import Foundation
import UserNotifications
import FirebaseFirestore
import BackgroundTasks

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    static let dailySummaryTaskID = "com.davidwu.financetracker.dailySummary"
    static let inactivityTaskID = "com.davidwu.financetracker.inactivityCheck"
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
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
                    print("Notification permission error: \(error)")
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
    
    func sendTransactionNotification(amount: Double, category: String, type: String) {
        // Auto-request permission if needed
        checkPermissionStatus { status in
            if status == .notDetermined {
                self.requestPermission { granted in
                    if granted {
                        self.sendNotification(amount: amount, category: category, type: type)
                    } else {
                        print("❌ Notification permission denied")
                    }
                }
            } else if status == .authorized || status == .provisional {
                self.sendNotification(amount: amount, category: category, type: type)
            } else {
                print("❌ Notifications not authorized. Status: \(status.rawValue)")
            }
        }
    }
    
    private func sendNotification(amount: Double, category: String, type: String) {
        // Check if transaction notifications are enabled (optional for now)
        let isEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled_transactions")
        print("🔔 Notification toggle enabled: \(isEnabled)")
        
        // Send anyway for debugging - remove this line in production
         guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        
        if type == "income" {
            content.title = "Income Received"
            content.body = "You received $\(Int(abs(amount))) from \(category)"
        } else {
            content.title = "Expense Added"
            content.body = "You have spent $\(Int(abs(amount))) on \(category)"
        }
        
        content.sound = .default
        content.badge = 1
        
        print("🔔 Scheduling notification: \(content.title) - \(content.body)")
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send transaction notification: \(error)")
            } else {
                print("✅ Notification scheduled successfully!")
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
                print("Failed to send budget warning: \(error)")
            }
        }
    }
    
    // MARK: - Daily Summary
    
    func scheduleDailySummary() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_dailySummary") else { return }
        
        let request = BGAppRefreshTaskRequest(identifier: Self.dailySummaryTaskID)
        // Earliest begin date: Tonight at 9 PM (or tomorrow 9 PM if passed)
        request.earliestBeginDate = getNextNinePM()
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled background task for \(request.earliestBeginDate?.description ?? "unknown")")
        } catch {
            print("❌ Could not schedule background task: \(error)")
        }
    }
    
    private func getNextNinePM() -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 21 // 9 PM
        components.minute = 0
        
        guard let ninePM = calendar.date(from: components) else { return now.addingTimeInterval(3600) }
        
        if ninePM < now {
            return calendar.date(byAdding: .day, value: 1, to: ninePM)!
        }
        return ninePM
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
                    print("Error fetching daily transactions: \(error)")
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
                    
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // Deliver immediately
                    UNUserNotificationCenter.current().add(request)
                }
                
                task.setTaskCompleted(success: true)
            }
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
                print("Failed to schedule weekly report: \(error)")
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
            print("✅ Scheduled inactivity check")
        } catch {
            print("❌ Could not schedule inactivity task: \(error)")
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
                    print("Error checking inactivity: \(error)")
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
                print("Failed to schedule EOD check: \(error)")
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
        
        // Handle Travel Notification
        if let type = userInfo["type"] as? String, type == "travel_update" {
             DispatchQueue.main.async {
                 AppState.shared.showProfile = true
                 
                 // Delay slightly to ensure Profile View is mounted before triggering navigation
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                     AppState.shared.shouldOpenCurrencySettings = true
                 }
             }
        }
        
        // Handle Daily Summary Deep Link
        if let timestamp = userInfo["date"] as? TimeInterval {
            let date = Date(timeIntervalSince1970: timestamp)
            DispatchQueue.main.async {
                AppState.shared.dailySummaryDate = date
                AppState.shared.showDailySummary = true
            }
        }
        
        completionHandler()
    }
}
