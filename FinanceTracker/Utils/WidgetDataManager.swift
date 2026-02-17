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
        static let dailyVault = "widget_dailyVault"
        static let dailySpendDate = "widget_dailySpend_date"
        static let monthlySpend = "widget_monthlySpend"
        static let monthlyBudget = "widget_monthlyBudget"
        static let lastUpdated = "widget_lastUpdated"
        
        static let recentTransactions = "widget_recentTransactions"
        static let quickLogCategories = "widget_quickLogCategories"
    }
    
    // MARK: - Models
    struct WidgetTransaction: Codable, Identifiable {
        let id: String
        let title: String
        let amount: Double
        let date: Date
        let icon: String
        let colorHex: String
    }
    
    struct WidgetCategory: Codable, Identifiable {
        var id: String { name }
        let name: String
        let icon: String
        let colorHex: String
    }
    
    // MARK: - Save Methods
    
    func saveDailyData(expense: Double, vault: Double) {
        userDefaults?.set(expense, forKey: Keys.dailySpend)
        userDefaults?.set(vault, forKey: Keys.dailyVault)
        userDefaults?.set(Date(), forKey: Keys.dailySpendDate)
        userDefaults?.set(Date(), forKey: Keys.lastUpdated)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func saveMonthlySpend(_ amount: Double) {
        userDefaults?.set(amount, forKey: Keys.monthlySpend)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func saveMonthlyBudget(_ amount: Double) {
        userDefaults?.set(amount, forKey: Keys.monthlyBudget)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func saveRecentTransactions(_ transactions: [WidgetTransaction]) {
        if let encoded = try? JSONEncoder().encode(transactions) {
            userDefaults?.set(encoded, forKey: Keys.recentTransactions)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func saveQuickLogCategories(_ categories: [WidgetCategory]) {
        if let encoded = try? JSONEncoder().encode(categories) {
            userDefaults?.set(encoded, forKey: Keys.quickLogCategories)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // MARK: - Fetch Methods
    
    func getDailySpend() -> Double {
        guard let lastDate = userDefaults?.object(forKey: Keys.dailySpendDate) as? Date else {
            return 0.0
        }
        
        if Calendar.current.isDateInToday(lastDate) {
            return userDefaults?.double(forKey: Keys.dailySpend) ?? 0.0
        } else {
            return 0.0
        }
    }
    
    func getDailyVault() -> Double {
        guard let lastDate = userDefaults?.object(forKey: Keys.dailySpendDate) as? Date else {
            return 0.0
        }
        
        if Calendar.current.isDateInToday(lastDate) {
            return userDefaults?.double(forKey: Keys.dailyVault) ?? 0.0
        } else {
            return 0.0
        }
    }
    
    func getMonthlySpend() -> Double {
        return userDefaults?.double(forKey: Keys.monthlySpend) ?? 0.0
    }
    
    func getMonthlyBudget() -> Double {
        return userDefaults?.double(forKey: Keys.monthlyBudget) ?? 0.0
    }
    
    func getRecentTransactions() -> [WidgetTransaction] {
        guard let data = userDefaults?.data(forKey: Keys.recentTransactions) else { return [] }
        return (try? JSONDecoder().decode([WidgetTransaction].self, from: data)) ?? []
    }
    
    func getQuickLogCategories() -> [WidgetCategory] {
        guard let data = userDefaults?.data(forKey: Keys.quickLogCategories) else { return [] }
        return (try? JSONDecoder().decode([WidgetCategory].self, from: data)) ?? []
    }
}
