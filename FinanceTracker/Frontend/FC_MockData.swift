// MARK: - FC_MockData.swift
// Frontend layer — mock/static data for Figma previews.
// All data is hardcoded. No Firebase or network calls.
// Used by every FC_ component and screen preview file.

import SwiftUI

// MARK: - Mock Transactions

enum FC_MockData {

    // MARK: - Categories (mirrors real CategoryBudget records)
    static let categories: [MockCategory] = [
        MockCategory(id: "cat-food",        name: "Food & Drink",   icon: "fork.knife",              colorHex: "#FF9500"),
        MockCategory(id: "cat-transport",   name: "Transport",      icon: "car.fill",                colorHex: "#007AFF"),
        MockCategory(id: "cat-shopping",    name: "Shopping",       icon: "bag.fill",                colorHex: "#AF52DE"),
        MockCategory(id: "cat-health",      name: "Health",         icon: "heart.fill",              colorHex: "#FF2D55"),
        MockCategory(id: "cat-home",        name: "Home",           icon: "house.fill",              colorHex: "#34C759"),
        MockCategory(id: "cat-entertain",   name: "Entertainment",  icon: "tv.fill",                 colorHex: "#5856D6"),
        MockCategory(id: "cat-income",      name: "Income",         icon: "dollarsign.circle.fill",  colorHex: "#34C759", type: "income"),
    ]

    static func category(id: String) -> MockCategory {
        categories.first { $0.id == id } ?? categories[0]
    }

    // MARK: - Transactions
    static let transactions: [MockTransaction] = [
        MockTransaction(id: "t1",  categoryId: "cat-food",       title: "Food & Drink",  note: "Sweetgreen",       amount: -18.50,  daysAgo: 0),
        MockTransaction(id: "t2",  categoryId: "cat-transport",  title: "Transport",     note: "Uber",             amount: -12.00,  daysAgo: 0),
        MockTransaction(id: "t3",  categoryId: "cat-shopping",   title: "Shopping",      note: "Amazon",           amount: -64.99,  daysAgo: 1),
        MockTransaction(id: "t4",  categoryId: "cat-income",     title: "Income",        note: "Paycheck",         amount: 2400.00, daysAgo: 1),
        MockTransaction(id: "t5",  categoryId: "cat-health",     title: "Health",        note: "CVS Pharmacy",     amount: -22.40,  daysAgo: 2),
        MockTransaction(id: "t6",  categoryId: "cat-home",       title: "Home",          note: "Con Edison",       amount: -89.00,  daysAgo: 3),
        MockTransaction(id: "t7",  categoryId: "cat-entertain",  title: "Entertainment", note: "Netflix",          amount: -15.99,  daysAgo: 4),
        MockTransaction(id: "t8",  categoryId: "cat-food",       title: "Food & Drink",  note: "Starbucks",        amount: -7.25,   daysAgo: 5),
        MockTransaction(id: "t9",  categoryId: "cat-transport",  title: "Transport",     note: "MTA Metro Card",   amount: -34.00,  daysAgo: 6),
        MockTransaction(id: "t10", categoryId: "cat-shopping",   title: "Shopping",      note: nil,                amount: -120.00, daysAgo: 7),
    ]

    // MARK: - Budgets
    static let budgets: [MockBudget] = [
        MockBudget(categoryId: "cat-food",       limit: 400,  spent: 310),
        MockBudget(categoryId: "cat-transport",  limit: 200,  spent: 46),
        MockBudget(categoryId: "cat-shopping",   limit: 300,  spent: 185),
        MockBudget(categoryId: "cat-health",     limit: 150,  spent: 22),
        MockBudget(categoryId: "cat-home",       limit: 1200, spent: 89),
        MockBudget(categoryId: "cat-entertain",  limit: 100,  spent: 16),
    ]

    // MARK: - Saving Goals
    static let savingGoals: [MockSavingGoal] = [
        MockSavingGoal(id: "g1", name: "Vacation",    targetAmount: 3000, currentAmount: 1250, icon: "airplane",       colorHex: "#007AFF"),
        MockSavingGoal(id: "g2", name: "MacBook Pro", targetAmount: 2499, currentAmount: 890,  icon: "laptopcomputer", colorHex: "#5856D6"),
        MockSavingGoal(id: "g3", name: "Emergency",   targetAmount: 5000, currentAmount: 2100, icon: "shield.fill",    colorHex: "#34C759"),
    ]

    // MARK: - Recurring Transactions
    static let recurringTransactions: [MockRecurring] = [
        MockRecurring(id: "r1", title: "Netflix",        amount: -15.99, icon: "tv.fill",         colorHex: "#5856D6", frequency: "Monthly"),
        MockRecurring(id: "r2", title: "Spotify",        amount: -9.99,  icon: "music.note",      colorHex: "#34C759", frequency: "Monthly"),
        MockRecurring(id: "r3", title: "Gym Membership", amount: -49.00, icon: "dumbbell.fill",   colorHex: "#FF2D55", frequency: "Monthly"),
        MockRecurring(id: "r4", title: "Salary",         amount: 4200.0, icon: "briefcase.fill",  colorHex: "#FF9500", frequency: "Monthly"),
    ]

    // MARK: - Groups
    static let groups: [MockGroup] = [
        MockGroup(id: "gr1", name: "Hawaii Trip",    icon: "airplane",      colorHex: "#007AFF", memberCount: 4, totalBalance: -230.00),
        MockGroup(id: "gr2", name: "Apartment",      icon: "house.fill",    colorHex: "#34C759", memberCount: 3, totalBalance: -45.00),
        MockGroup(id: "gr3", name: "Dinner Club",    icon: "fork.knife",    colorHex: "#FF9500", memberCount: 5, totalBalance: 60.00),
    ]

    // MARK: - Friends
    static let friends: [MockFriend] = [
        MockFriend(id: "f1", name: "Alex R.",    username: "alexr",    avatarColor: "#007AFF", owedAmount: -45.00),
        MockFriend(id: "f2", name: "Sam T.",     username: "samtee",   avatarColor: "#AF52DE", owedAmount: 120.00),
        MockFriend(id: "f3", name: "Jordan K.",  username: "jordank",  avatarColor: "#FF9500", owedAmount: -15.50),
        MockFriend(id: "f4", name: "Morgan L.",  username: "morganl",  avatarColor: "#34C759", owedAmount: 0),
    ]

    // MARK: - User Profile
    static let userProfile = MockProfile(
        name: "David W.",
        username: "daviidwuu",
        avatarColor: "#FF9500",
        isPremium: true,
        streakCount: 12,
        totalPoints: 2450,
        monthlyIncome: 4200
    )

    // MARK: - Aggregate numbers (for Home balance card)
    static let totalSpent: Double      = 355.13
    static let totalBudget: Double     = 2350.0
    static let netWorth: Double        = 14_820.50
}

// MARK: - Mock Model Types (no Firebase dependency)

struct MockCategory: Identifiable {
    var id: String
    var name: String
    var icon: String
    var colorHex: String
    var type: String = "expense"
    var color: Color { Color(hex: colorHex) }
}

struct MockTransaction: Identifiable {
    var id: String
    var categoryId: String
    var title: String
    var note: String?
    var amount: Double
    var daysAgo: Int
    var date: Date { Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date() }
    var hasSplit: Bool = false
}

struct MockBudget: Identifiable {
    var id: String { categoryId }
    var categoryId: String
    var limit: Double
    var spent: Double
    var progress: Double { min(spent / limit, 1.0) }
    var remaining: Double { max(limit - spent, 0) }
}

struct MockSavingGoal: Identifiable {
    var id: String
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var icon: String
    var colorHex: String
    var progress: Double { min(currentAmount / targetAmount, 1.0) }
    var color: Color { Color(hex: colorHex) }
    var targetDate: Date { Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date() }
}

struct MockRecurring: Identifiable {
    var id: String
    var title: String
    var amount: Double
    var icon: String
    var colorHex: String
    var frequency: String
    var color: Color { Color(hex: colorHex) }
}

struct MockGroup: Identifiable {
    var id: String
    var name: String
    var icon: String
    var colorHex: String
    var memberCount: Int
    var totalBalance: Double
}

struct MockFriend: Identifiable {
    var id: String
    var name: String
    var username: String
    var avatarColor: String
    var owedAmount: Double
    var color: Color { Color(hex: avatarColor) }
    var initial: String { String(name.prefix(1)) }
}

struct MockProfile {
    var name: String
    var username: String
    var avatarColor: String
    var isPremium: Bool
    var streakCount: Int
    var totalPoints: Int
    var monthlyIncome: Double
    var color: Color { Color(hex: avatarColor) }
    var initial: String { String(name.prefix(1)) }
}

// MARK: - Date / Amount Formatting Helpers (no CurrencyFormatter dependency)

extension MockTransaction {
    var formattedDate: String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        let time = fmt.string(from: date)
        if cal.isDateInToday(date)     { return "Today at \(time)" }
        if cal.isDateInYesterday(date) { return "Yesterday at \(time)" }
        fmt.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(fmt.string(from: date)) at \(time)"
    }

    var formattedAmount: String {
        let prefix = amount >= 0 ? "+" : "-"
        return "\(prefix)$\(String(format: "%.2f", abs(amount)))"
    }

    var amountColor: Color {
        amount >= 0 ? Color.functionalSuccess : Color.primary
    }
}
