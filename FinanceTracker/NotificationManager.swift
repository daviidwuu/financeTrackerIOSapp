import Foundation
import UserNotifications
import FirebaseFirestore

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
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
        // guard isEnabled else { return }
        
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
    
    func scheduleDailySummary(totalSpent: Double, transactionCount: Int) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled_dailySummary") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Summary"
        content.body = "Today: \(transactionCount) transactions, $\(Int(totalSpent)) spent"
        content.sound = .default
        
        // Schedule for 9 PM
        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-summary", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily summary: \(error)")
            }
        }
    }
    
    func cancelDailySummary() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-summary"])
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
    
    // MARK: - Clear Badges
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    // MARK: - Listen for Shortcut Transactions
    
    /// Start listening for new transactions added via shortcuts
    func startListeningForShortcutTransactions(userId: String) {
        let db = Firestore.firestore()
        
        // Listen for new transactions with source = "shortcuts"
        db.collection("users").document(userId).collection("transactions")
            .whereField("source", isEqualTo: "shortcuts")
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    print("Error listening for shortcut transactions: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                // Only process new documents (not initial load)
                snapshot.documentChanges.forEach { change in
                    if change.type == .added {
                        let data = change.document.data()
                        
                        // Extract transaction details
                        let amount = data["amount"] as? Double ?? 0
                        let category = data["title"] as? String ?? "Unknown"
                        let type = data["type"] as? String ?? "expense"
                        
                        // Send notification
                        print("🔔 Detected shortcut transaction: \(category) - $\(abs(amount))")
                        self.sendTransactionNotification(
                            amount: amount,
                            category: category,
                            type: type
                        )
                    }
                }
            }
    }
}
