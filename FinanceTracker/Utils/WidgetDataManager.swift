import Foundation
import WidgetKit

class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // REPLACE WITH YOUR ACTUAL APP GROUP ID
    private let appGroup = "group.com.wu.FinanceTracker"
    
    private var userDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroup)
    }
    
    // MARK: - Keys
    private struct Keys {
        static let dailySpend = "widget_dailySpend"
        static let dailySpendDate = "widget_dailySpend_date" // New key
        static let monthlySpend = "widget_monthlySpend"
        static let monthlyBudget = "widget_monthlyBudget"
        static let lastUpdated = "widget_lastUpdated"
    }
    
    // MARK: - Save Methods
    func saveDailySpend(_ amount: Double) {
        userDefaults?.set(amount, forKey: Keys.dailySpend)
        userDefaults?.set(Date(), forKey: Keys.dailySpendDate) // Save date
        updateTimestamp()
    }
    
    func saveMonthlySpend(_ amount: Double) {
        userDefaults?.set(amount, forKey: Keys.monthlySpend)
        updateTimestamp()
    }
    
    func saveMonthlyBudget(_ amount: Double) {
        userDefaults?.set(amount, forKey: Keys.monthlyBudget)
        reloadWidget()
    }
    
    private func updateTimestamp() {
        userDefaults?.set(Date(), forKey: Keys.lastUpdated)
        reloadWidget()
    }
    
    private func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Fetch Methods (For Widget)
    func getDailySpend() -> Double {
        // Check date validity
        if let lastDate = userDefaults?.object(forKey: Keys.dailySpendDate) as? Date {
            if !Calendar.current.isDateInToday(lastDate) {
                return 0.0 // Reset if not today
            }
        }
        return userDefaults?.double(forKey: Keys.dailySpend) ?? 0.0
    }
    
    func getMonthlySpend() -> Double {
        return userDefaults?.double(forKey: Keys.monthlySpend) ?? 0.0
    }
    
    func getMonthlyBudget() -> Double {
        return userDefaults?.double(forKey: Keys.monthlyBudget) ?? 0.0
    }
    
    func getLastUpdated() -> Date {
        return userDefaults?.object(forKey: Keys.lastUpdated) as? Date ?? Date()
    }
}
