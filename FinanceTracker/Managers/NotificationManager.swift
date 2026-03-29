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
        let viewAction = UNNotificationAction(identifier: NotificationContent.Action.view, title: "View Details", options: .foreground)
        let transactionCategory = UNNotificationCategory(identifier: NotificationContent.Category.transaction, actions: [viewAction], intentIdentifiers: [], options: .customDismissAction)

        // Split Actions
        let remindAction = UNNotificationAction(identifier: NotificationContent.Action.remind, title: "Remind Friend", options: .foreground)
        let splitCategory = UNNotificationCategory(identifier: NotificationContent.Category.split, actions: [remindAction], intentIdentifiers: [], options: .customDismissAction)

        // Daily Summary Actions
        let analyticsAction = UNNotificationAction(identifier: NotificationContent.Action.analytics, title: "View Analytics", options: .foreground)
        let summaryCategory = UNNotificationCategory(identifier: NotificationContent.Category.dailySummary, actions: [analyticsAction], intentIdentifiers: [], options: .customDismissAction)

        // Bill Reminder Actions
        let payAction = UNNotificationAction(identifier: NotificationContent.Action.pay, title: "Mark Paid", options: .foreground)
        let billCategory = UNNotificationCategory(identifier: NotificationContent.Category.bill, actions: [payAction], intentIdentifiers: [], options: .customDismissAction)

        // Streak Actions
        let logAction = UNNotificationAction(identifier: NotificationContent.Action.log, title: "Log Now", options: .foreground)
        let streakCategory = UNNotificationCategory(identifier: NotificationContent.Category.streak, actions: [logAction], intentIdentifiers: [], options: .customDismissAction)

        // Budget category (no custom actions)
        let budgetCategory = UNNotificationCategory(identifier: NotificationContent.Category.budget, actions: [], intentIdentifiers: [], options: .customDismissAction)

        UNUserNotificationCenter.current().setNotificationCategories([
            transactionCategory,
            splitCategory,
            summaryCategory,
            billCategory,
            streakCategory,
            budgetCategory
        ])
    }

    // MARK: - Content Builder

    /// Creates a `UNMutableNotificationContent` from a factory message tuple.
    func makeContent(message: (title: String, body: String), category: String, badge: Int? = nil) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        if !category.isEmpty {
            content.categoryIdentifier = category
        }
        if let badge = badge {
            content.badge = badge as NSNumber
        }
        return content
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
                if granted {
                    self.enableDefaultNotificationPreferences()
                }
                completion(granted)
            }
        }
    }

    /// Enables sensible default notification preferences when the user first grants permission.
    /// Only sets defaults if no preferences have been configured yet (i.e., all are still false).
    func enableDefaultNotificationPreferences() {
        let defaults = UserDefaults.standard

        // Check if user has already configured preferences (any toggle is true)
        let keys = [
            "notificationsEnabled_transactions",
            "notificationsEnabled_budgets",
            "notificationsEnabled_dailySummary",
            "notificationsEnabled_weeklyReport",
            "notificationsEnabled_inactivity",
            "notificationsEnabled_eod",
            "notificationsEnabled_tips",
            "notificationsEnabled_unpaidSplits",
            "notificationsEnabled_goals",
            "notificationsEnabled_billReminders",
            "notificationsEnabled_streaks",
            "notificationsEnabled_largeExpense"
        ]

        let anyEnabled = keys.contains { defaults.bool(forKey: $0) }
        guard !anyEnabled else { return }

        // Enable core notification types by default
        defaults.set(true, forKey: "notificationsEnabled_transactions")
        defaults.set(true, forKey: "notificationsEnabled_budgets")
        defaults.set(true, forKey: "notificationsEnabled_dailySummary")
        defaults.set(true, forKey: "notificationsEnabled_billReminders")
        defaults.set(true, forKey: "notificationsEnabled_unpaidSplits")
        defaults.set(true, forKey: "notificationsEnabled_streaks")
        defaults.set(true, forKey: "notificationsEnabled_largeExpense")

        DebugLogger.log("✅ Default notification preferences enabled")

        // Schedule the notifications that need scheduling
        scheduleDailySummary()
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
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_transactions") else { return }

        // Large Expense Check
        let threshold = UserDefaults.standard.double(forKey: "largeExpenseThreshold")
        if threshold > 0 && abs(amount) >= threshold && type != "income" {
            sendLargeExpenseAlert(amount: abs(amount))
        }

        let userName = AppState.shared.userName
        let message = NotificationContent.getMessage(
            for: .transaction(amount: amount, category: category, type: type, originalAmount: originalAmount, currencyCode: currencyCode),
            userName: userName
        )

        let content = makeContent(message: message, category: NotificationContent.Category.transaction, badge: 1)

        DebugLogger.log("🔔 Scheduling notification: \(message.title) - \(message.body)")

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DebugLogger.log("❌ Failed to send transaction notification: \(error)")
            } else {
                DebugLogger.log("✅ Notification scheduled successfully")
            }
        }
    }
    
    private func sendLargeExpenseAlert(amount: Double) {
        let userName = AppState.shared.userName
        let message = NotificationContent.getMessage(for: .largeExpense(amount: amount), userName: userName)
        let content = makeContent(message: message, category: NotificationContent.Category.transaction)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "large-expense-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Budget Notifications
    
    func sendBudgetWarning(category: String, percentUsed: Int, remaining: Double) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_budgets") else { return }

        let userName = AppState.shared.userName
        let message = NotificationContent.getMessage(for: .budgetHit(category: category, percent: percentUsed), userName: userName)
        let content = makeContent(message: message, category: NotificationContent.Category.budget)

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
                    let userName = AppState.shared.userName
                    let message = NotificationContent.getMessage(for: .dailySummary(totalSpent: totalSpent, count: count), userName: userName)
                    let content = self.makeContent(message: message, category: NotificationContent.Category.dailySummary)
                    content.userInfo = ["date": Date().timeIntervalSince1970]

                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
                
                // Concurrent Checks
                let group = DispatchGroup()
                
                group.enter()
                self.checkSplitBillReminders { group.leave() }
                
                group.enter()
                self.checkBillDueReminders { group.leave() }
                
                group.notify(queue: .main) {
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
                            let transaction = try doc.data(as: FirestoreModels.TransactionModel.self)
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
        let userName = AppState.shared.userName
        let message = NotificationContent.getMessage(for: .splitReminder(count: count, total: total), userName: userName)
        let content = makeContent(message: message, category: NotificationContent.Category.split)

        let request = UNNotificationRequest(identifier: "split-reminder-\(Date().timeIntervalSince1970)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Bill Reminders
    
    func checkBillDueReminders(completion: @escaping () -> Void = {}) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_billReminders") else {
            completion()
            return
        }
        
        let userId = AppState.shared.currentUserId
        guard !userId.isEmpty else {
            completion()
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("recurring_transactions")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents, error == nil else {
                    completion()
                    return
                }
                
                let calendar = Calendar.current
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
                
                Task { @MainActor in
                    for doc in documents {
                        do {
                            let recurring = try doc.data(as: FirestoreModels.RecurringTransaction.self)
                            let dayOfStart = calendar.component(.day, from: recurring.startDate)
                            let dayOfTomorrow = calendar.component(.day, from: tomorrow)
                            
                            if dayOfStart == dayOfTomorrow {
                                self.sendBillReminder(recurring: recurring)
                            }
                        } catch {
                            continue
                        }
                    }
                    completion()
                }
            }
    }
    
    private func sendBillReminder(recurring: FirestoreModels.RecurringTransaction) {
        let userName = AppState.shared.userName
        let message = NotificationContent.getMessage(for: .billDue(name: recurring.name, amount: recurring.amount), userName: userName)
        let content = makeContent(message: message, category: NotificationContent.Category.bill)
        content.userInfo = ["recurringId": recurring.id ?? ""]

        let request = UNNotificationRequest(identifier: "bill-reminder-\(recurring.id ?? UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Weekly Report
    
    func scheduleWeeklyReport() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_weeklyReport") else { return }

        let userName = AppState.shared.userName
        let message = NotificationContent.getMessage(for: .weeklyReport, userName: userName)
        let content = makeContent(message: message, category: "")

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
                    
                    // Check Streak Warning Logic
                    if UserDefaults.standard.bool(forKey: "notificationsEnabled_streaks") {
                        self.checkStreakWarning(userId: userId)
                    } else {
                        self.sendInactivityNotification()
                    }
                }
                
                task.setTaskCompleted(success: true)
            }
    }
    
    private func sendInactivityNotification() {
        let userName = AppState.shared.userName
        let message = NotificationContent.getMessage(for: .inactivity, userName: userName)
        let content = makeContent(message: message, category: NotificationContent.Category.inactivity)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func checkStreakWarning(userId: String) {
        // Simplification: Send streak warning if inactivity is detected late in the day (after 6 PM)
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 18 {
             let userName = AppState.shared.userName
             let message = NotificationContent.getMessage(for: .streakWarning(daysConfig: 1), userName: userName)
             let content = makeContent(message: message, category: NotificationContent.Category.streak)

             let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
             UNUserNotificationCenter.current().add(request)
        } else {
            // Normal inactivity
            sendInactivityNotification()
        }
    }
    
    // MARK: - End of Day Check
    
    func scheduleEODCheck() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_eod") else { return }
        
        // Retrieve custom time or default to 10 PM
        let storedSeconds = UserDefaults.standard.double(forKey: "eodCheckTime")
        let totalSeconds = storedSeconds > 0 ? Int(storedSeconds) : 79200 // 22 * 3600
        
        let hour = totalSeconds / 3600
        let minute = (totalSeconds % 3600) / 60
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let userName = AppState.shared.userName
        let message = NotificationContent.getMessage(for: .endOfDay, userName: userName)
        let content = makeContent(message: message, category: "")

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
        
        // Retrieve custom times
        let morningSeconds = UserDefaults.standard.double(forKey: "motivationalTime_morning")
        let eveningSeconds = UserDefaults.standard.double(forKey: "motivationalTime_evening")
        
        let morningHour = morningSeconds > 0 ? Int(morningSeconds) / 3600 : 7
        let eveningHour = eveningSeconds > 0 ? Int(eveningSeconds) / 3600 : 19
        
        let hours = [morningHour, 10, 13, 16, eveningHour]
        let userName = AppState.shared.userName
        
        for hour in hours {
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            let message = NotificationContent.getMessage(for: .motivational, userName: userName)
            let content = makeContent(message: message, category: "")

            let request = UNNotificationRequest(identifier: "tip-\(hour)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func cancelMotivationalTips() {
        // Remove all requests that start with "tip-"
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let tipIds = requests.filter { $0.identifier.hasPrefix("tip-") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: tipIds)
        }
    }
    
    // MARK: - Clear Badges
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    

    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let categoryId = response.notification.request.content.categoryIdentifier
        let actionId = response.actionIdentifier

        // Route notification taps through focused state objects rather than the
        // full AppState graph.  Tab/sheet routing goes to AppNavigationState;
        // showProfile (which HomeView binds to) stays on AppState.
        let nav = AppNavigationState.shared

        // Handle Travel Notification
        if let type = userInfo["type"] as? String, type == "travel_update" {
             DispatchQueue.main.async {
                 AppState.shared.showProfile = true

                 // Delay slightly to ensure Profile View is mounted before triggering navigation
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                     nav.shouldOpenCurrencySettings = true
                 }
             }

        // --- 1. Daily Summary (Deep Link) ---
        } else if categoryId == NotificationContent.Category.dailySummary || actionId == NotificationContent.Action.analytics {
            if let timestamp = userInfo["date"] as? TimeInterval {
                let date = Date(timeIntervalSince1970: timestamp)
                DispatchQueue.main.async {
                    nav.dailySummaryDate = date
                    nav.showDailySummary = true
                }
            } else {
                 DispatchQueue.main.async {
                     nav.dailySummaryDate = Date()
                     nav.showDailySummary = true
                 }
            }

        // --- 2. Transactions (View Details) ---
        } else if categoryId == NotificationContent.Category.transaction || actionId == NotificationContent.Action.view {
            DispatchQueue.main.async {
                nav.selectedTab = 0
            }

        // --- 3. Split Reminders (Friends/Profile) ---
        } else if categoryId == NotificationContent.Category.split || actionId == NotificationContent.Action.remind {
            DispatchQueue.main.async {
                AppState.shared.showProfile = true
            }

        // --- 4. Budget Alerts (Wallet Tab) ---
        } else if categoryId == NotificationContent.Category.budget {
             DispatchQueue.main.async {
                 nav.selectedTab = 1
             }

        // --- 5. Inactivity/Streak Check (Prompt to Add Transaction) ---
        } else if categoryId == NotificationContent.Category.inactivity || categoryId == NotificationContent.Category.streak || actionId == NotificationContent.Action.log {
             DispatchQueue.main.async {
                 nav.selectedTab = 0
                 if let url = URL(string: "financetracker://add-transaction") {
                     UIApplication.shared.open(url)
                 }
             }

        // --- 6. Weekly Report (Summary) ---
        } else if response.notification.request.identifier == "weekly-report" {
             DispatchQueue.main.async {
                 nav.showWeeklyReport = true
             }

        // --- 7. Bill Reminders ---
        } else if categoryId == NotificationContent.Category.bill {
             DispatchQueue.main.async {
                 nav.selectedTab = 1
             }

        // --- 8. Goal Milestones (Wallet Tab) ---
        } else if categoryId == "GOAL" {
             DispatchQueue.main.async {
                 nav.selectedTab = 1
             }
        }

        completionHandler()
    }

    // MARK: - MessagingDelegate
    
    private var cachedFCMToken: String?
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        DebugLogger.log("FCM Token received (length: \(token.count))")
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
