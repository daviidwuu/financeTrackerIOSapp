import Foundation

struct NotificationContent {

    // MARK: - Category Identifiers

    enum Category {
        static let transaction = "TRANSACTION"
        static let split = "SPLIT"
        static let budget = "BUDGET"
        static let bill = "BILL"
        static let streak = "STREAK"
        static let inactivity = "INACTIVITY"
        static let dailySummary = "DAILY_SUMMARY"
    }

    // MARK: - Action Identifiers

    enum Action {
        static let view = "VIEW_ACTION"
        static let remind = "REMIND_ACTION"
        static let analytics = "ANALYTICS_ACTION"
        static let pay = "PAY_ACTION"
        static let log = "LOG_ACTION"
    }

    // MARK: - Message Types

    enum MessageType {
        case inactivity
        case endOfDay
        case motivational
        case billDue(name: String, amount: Double)
        case streakWarning(daysConfig: Int)
        case largeExpense(amount: Double)
        case budgetHit(category: String, percent: Int)
        case transaction(amount: Double, category: String, type: String, originalAmount: Double?, currencyCode: String?)
        case dailySummary(totalSpent: Double, count: Int)
        case splitReminder(count: Int, total: Double)
        case weeklyReport
        case travelCountryChange(countryName: String)
    }

    // MARK: - Shared Helpers

    static func formatCurrency(_ amount: Double) -> String {
        String(format: "$%.2f", abs(amount))
    }

    static func formatCurrencyInt(_ amount: Double) -> String {
        "$\(Int(abs(amount)))"
    }

    // MARK: - Factory

    static func getMessage(for type: MessageType, userName: String) -> (title: String, body: String) {
        let name = userName.isEmpty ? "there" : userName
        let hour = Calendar.current.component(.hour, from: Date())

        switch type {

        case .inactivity:
            return getInactivityMessage(name: name, hour: hour)

        case .endOfDay:
            return getEODMessage(name: name)

        case .motivational:
            return getMotivationalMessage(name: name, hour: hour)

        case .billDue(let billName, let amount):
            return (
                "Bill due tomorrow",
                "\(billName) (\(formatCurrency(amount))) is due tomorrow — make sure you have funds ready."
            )

        case .streakWarning(let days):
            return (
                "Keep your streak alive",
                "You haven't logged a transaction in \(days) hour\(days == 1 ? "" : "s") — open the app to stay on track."
            )

        case .largeExpense(let amount):
            return (
                "Large expense logged",
                "You just logged \(formatCurrency(amount)) — make sure this was planned."
            )

        case .budgetHit(let category, let percent):
            return (
                "Budget update",
                "You've used \(percent)% of your \(category) budget for this month."
            )

        case .transaction(let amount, let category, let type, let originalAmount, let currencyCode):
            return getTransactionMessage(
                amount: amount,
                category: category,
                type: type,
                originalAmount: originalAmount,
                currencyCode: currencyCode
            )

        case .dailySummary(let totalSpent, let count):
            return (
                "Daily summary",
                "You spent \(formatCurrencyInt(totalSpent)) across \(count) transaction\(count == 1 ? "" : "s") today."
            )

        case .splitReminder(let count, let total):
            let plural = count == 1 ? "split" : "splits"
            return (
                "Unpaid splits",
                "You have \(count) unpaid \(plural) totaling \(formatCurrencyInt(total)) — check if friends have paid you back."
            )

        case .weeklyReport:
            return (
                "Weekly report ready",
                "Your weekly spending summary is ready to review."
            )

        case .travelCountryChange(let countryName):
            return (
                "Welcome to \(countryName)",
                "Tap to set up your travel currency for \(countryName)."
            )
        }
    }

    // MARK: - Inactivity Messages

    private static func getInactivityMessage(name: String, hour: Int) -> (String, String) {
        let title = "Quick check-in"
        let morning = [
            "Busy morning? Just checking if you missed any expenses.",
            "Did your money fly this morning, \(name)? Log it if so.",
            "Don't forget to log that morning coffee or commute.",
            "Anything to add before the day gets going, \(name)?",
            "Start the day right by tracking every purchase.",
            "Did you buy breakfast? Log it now.",
            "Morning commute cost? Don't forget to track it.",
            "Fresh start today — keep your ledger fresh too.",
            "Quick finance check before the day gets busy, \(name)."
        ]

        let afternoon = [
            "Lunch break over? Don't forget to log what you spent.",
            "Afternoon check — have you logged today's spending, \(name)?",
            "Mid-day check: has your wallet been opened recently?",
            "Tracking is a habit — have you logged everything so far, \(name)?",
            "Don't let small afternoon purchases slip through the cracks.",
            "How's the budget looking this afternoon, \(name)?",
            "Half the day is gone — is your tracking halfway done?"
        ]

        let evening = [
            "Winding down? Make sure your expense log is up to date, \(name).",
            "Did you buy anything on the way home today?",
            "Don't let today's receipts become tomorrow's mystery.",
            "Dinner logged? If you bought it, track it.",
            "Keep the streak alive, \(name) — log any missing transactions.",
            "Take a moment to update your spending before you unplug.",
            "Did you order takeout tonight? Log that expense."
        ]

        var pool = [
            "Wallet feeling lighter? Make sure to track it.",
            "Just a friendly nudge to keep your ledger accurate.",
            "Every transaction counts — have you logged yours, \(name)?",
            "Stay on top of your finances — log it now.",
            "Your future self will thank you for tracking this today.",
            "Have you checked your budget today?"
        ]

        if hour < 12 { pool += morning }
        else if hour < 17 { pool += afternoon }
        else { pool += evening }

        return (title, pool.randomElement() ?? pool[0])
    }

    // MARK: - EOD Messages

    private static func getEODMessage(name: String) -> (String, String) {
        let title = "Daily wrap-up"
        let messages = [
            "Did you catch every transaction today, \(name)?",
            "One last look at your finances before you call it a day.",
            "Goodnight, \(name) — everything recorded for today?",
            "Everything in the ledger? Check today's activity.",
            "Sleep soundly knowing your finances are tracked.",
            "Zero transactions today, or just forgot to log them?",
            "Make tomorrow easier by finalising today's accounts.",
            "Did you hit your daily budget goals, \(name)?",
            "A clear mind needs clear finances — review your day.",
            "Is your balance up to date before you drift off, \(name)?",
            "End the day strong — verify your transactions.",
            "Any forgotten subscriptions or auto-pays today?",
            "Ready to close the books on today?",
            "Did you overspend or underspend today? Check now.",
            "Tomorrow is a new financial day — close today properly."
        ]
        return (title, messages.randomElement() ?? messages[0])
    }

    // MARK: - Motivational Messages

    private static func getMotivationalMessage(name: String, hour: Int) -> (String, String) {
        // 1. Check if AIContentManager has a fresh daily tip
        if let aiTip = AIContentManager.shared.dailyTip {
            // Cycle through possible AI titles
            let aiTitles = ["AI Insight", "Personalized Tip", "Wealth Guide", "Focus Mode", "Smart Suggestion"]
            return (aiTitles.randomElement()!, aiTip)
        }

        // 2. Check if Firebase Remote Config has custom tips
        let remoteTips = FirebaseManager.shared.getRemoteMotivationalTips()
        if !remoteTips.isEmpty {
            let titles = ["Wealth wisdom", "Pro tip", "Reality check", "Smart move"]
            return (titles.randomElement()!, remoteTips.randomElement()!)
        }

        // 3. Fallback to hardcoded list
        // Morning (6am–10am)
        if hour >= 6 && hour < 10 {
            let titles = ["Rise and shine", "Morning motivation", "Start strong", "Daily focus", "Wake up wealthy"]
            let messages = [
                "A new day to make smart financial choices, \(name).",
                "Good morning — start the day with a clear financial mind.",
                "New day, new opportunities to save.",
                "Wake up and build wealth — consistency is key.",
                "Today is a great day to stick to your budget.",
                "Your financial future is built one morning at a time.",
                "Coffee: $5. Financial freedom: priceless.",
                "Morning goal: spend less than you earn today.",
                "Set your financial intention for the day.",
                "The early bird catches the compound interest."
            ]
            return (titles.randomElement()!, messages.randomElement()!)
        }

        // Evening (6pm+)
        if hour >= 18 {
            let titles = ["Evening wisdom", "Financial peace", "Reflect", "Unwind and review", "Smart choices"]
            let messages = [
                "Peace of mind comes from knowing where you stand financially.",
                "Did today's spending align with your goals, \(name)?",
                "A penny saved is a penny earned — good evening.",
                "Relax — you're in control of your money.",
                "The best pillow is a clear conscience and a balanced budget.",
                "Did today's make your money work for you today?",
                "Wind down and review — you're doing great, \(name).",
                "If you bought something impulsively, it's okay — just track it.",
                "Reviewing your day is the best way to improve tomorrow.",
                "You are building a better future, one day at a time."
            ]
            return (titles.randomElement()!, messages.randomElement()!)
        }

        // General day
        let titles = ["Money tip", "Did you know?", "Stay focused", "Financial fact", "Smart move", "Wealth wisdom", "Pro tip", "Reality check"]
        let messages = [
            "A budget tells your money where to go instead of wondering where it went.",
            "Small leaks sink great ships — watch those small expenses.",
            "Don't save what's left after spending; spend what's left after saving.",
            "It's not your salary that makes you rich — it's your spending habits.",
            "The art is not in making money, but in keeping it.",
            "Every transaction counts towards your future, \(name).",
            "Invest in yourself by tracking your money.",
            "Don't go broke trying to look rich.",
            "Savings today means security tomorrow.",
            "Price is what you pay; value is what you get.",
            "Compound interest is the eighth wonder of the world.",
            "Live below your means to expand your means.",
            "Financial literacy is the best investment.",
            "Avoid lifestyle creep as your income grows.",
            "An emergency fund changes everything.",
            "Debt is a tool or a trap — use it wisely.",
            "Consistency beats intensity.",
            "Money is a terrible master but an excellent servant."
        ]
        return (titles.randomElement()!, messages.randomElement()!)
    }

    // MARK: - Transaction Message

    private static func getTransactionMessage(
        amount: Double,
        category: String,
        type: String,
        originalAmount: Double?,
        currencyCode: String?
    ) -> (String, String) {
        let formatted = formatCurrency(amount)
        var body: String

        if type == "income" {
            body = "You received \(formatted)"
        } else {
            body = "You spent \(formatted)"
        }

        if let original = originalAmount, let code = currencyCode {
            body += " (\(code) \(formatCurrency(original)))"
        }

        if type == "income" {
            body += " from \(category)"
        } else {
            body += " on \(category)"
        }

        let title = type == "income" ? "Income received" : "Expense added"
        return (title, body)
    }
}
