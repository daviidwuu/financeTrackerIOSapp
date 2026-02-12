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
        static let dailyVault = "widget_dailyVault" // New key
        static let dailySpendDate = "widget_dailySpend_date"
        static let monthlySpend = "widget_monthlySpend"
        static let monthlyBudget = "widget_monthlyBudget"
        static let lastUpdated = "widget_lastUpdated"
    }
    
    // MARK: - Save Methods
    func saveDailyData(expense: Double, vault: Double) {
        userDefaults?.set(expense, forKey: Keys.dailySpend)
        userDefaults?.set(vault, forKey: Keys.dailyVault)
        userDefaults?.set(Date(), forKey: Keys.dailySpendDate)
        updateTimestamp()
    }
    
    // Deprecated but kept for compatibility if needed (or just remove)
    func saveDailySpend(_ amount: Double) {
        saveDailyData(expense: amount, vault: 0)
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
        if !isToday() { return 0.0 }
        return userDefaults?.double(forKey: Keys.dailySpend) ?? 0.0
    }
    
    func getDailyVault() -> Double {
        if !isToday() { return 0.0 }
        return userDefaults?.double(forKey: Keys.dailyVault) ?? 0.0
    }
    
    private func isToday() -> Bool {
        guard let lastDate = userDefaults?.object(forKey: Keys.dailySpendDate) as? Date else { return false }
        return Calendar.current.isDateInToday(lastDate)
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
