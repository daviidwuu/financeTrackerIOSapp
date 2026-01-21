import Foundation

struct NotificationContent {
    enum MessageType {
        case inactivity
        case endOfDay
        case motivational
    }
    
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
        }
    }
    
    // MARK: - Inactivity Messages
    private static func getInactivityMessage(name: String, hour: Int) -> (String, String) {
        let title = "Quick Check-in"
        let morning = [
            "Busy morning, \(name)? Just checking if you missed any expenses.",
            "Hey \(name), the morning is flying by! Did your money fly too?",
            "Don't let the coffee buzz make you forget to log that latte, \(name).",
            "Morning transactions check! Anything to add, \(name)?",
            "Start the day right by tracking every penny, \(name)."
        ]
        
        let afternoon = [
            "Lunch break over? Don't forget to log what you spent, \(name).",
            "Afternoon slump? Wake up your wallet and track recent spends, \(name).",
            "Hey \(name), keeping up with the day's expenses?",
            "Mid-day check: Has your wallet been opened recently, \(name)?",
            "Tracking is a habit, \(name). Have you logged everything so far?"
        ]
        
        let evening = [
            "Winding down, \(name)? Make sure your expense log is up to date.",
            "Evening check-in! Did you buy anything on the way home, \(name)?",
            "Don't let today's receipts become tomorrow's mystery, \(name).",
            "Dinner time! If you bought it, track it, \(name).",
            "Keep the streak alive, \(name). Log any missing transactions."
        ]
        
        let general = [
            "Wallet feeling lighter? Make sure to track it, \(name)!",
            "\(name), tracking ensures freedom. Did you spend anything?",
            "Just a friendly nudge to keep your ledger accurate, \(name).",
            "Every transaction counts. Have you logged yours, \(name)?",
            "Stay on top of your finances, \(name). Log it now."
        ]
        
        var pool = general
        if hour < 12 { pool += morning }
        else if hour < 17 { pool += afternoon }
        else { pool += evening }
        
        return (title, pool.randomElement() ?? pool[0])
    }
    
    // MARK: - EOD Messages
    private static func getEODMessage(name: String) -> (String, String) {
        let title = "Daily Wrap-up"
        let messages = [
            "Time to wrap up, \(name). Did you catch every transaction today?",
            "10 PM Check: Review your day's spending to stay on track.",
            "Goodnight \(name)! One last look at your finances for the day?",
            "Closing the ledger for the day, \(name). Everything recorded?",
            "Sleep soundly knowing your finances are tracked. Check today's activity.",
            "Zero transactions today? Or just forgot to log them, \(name)?",
            "Make tomorrow easier by finalizing today's accounts, \(name).",
            "Did you hit your daily budget goals today, \(name)?",
            "A clear mind needs clear finances. Review your day, \(name).",
            "Before you drift off, is your Finance Tracker up to date, \(name)?"
        ]
        return (title, messages.randomElement() ?? messages[0])
    }
    
    // MARK: - Motivational Messages
    private static func getMotivationalMessage(name: String, hour: Int) -> (String, String) {
        // Morning (6am - 10am)
        if hour >= 6 && hour < 10 {
            let titles = ["Rise & Shine", "Morning Motivation", "Start Strong"]
            let messages = [
                "Rise and shine, \(name). A new day to make smart financial choices!",
                "Good morning \(name)! Start the day with a clear financial mind.",
                "New day, new opportunities to save, \(name).",
                "Wake up and build wealth, \(name). Consistency is key.",
                "Today is a perfect day to stick to your budget, \(name).",
                "Your financial future is built one morning at a time, \(name).",
                "Coffee: $5. Financial Freedom: Priceless. Good morning, \(name)!"
            ]
            return (titles.randomElement()!, messages.randomElement()!)
        }
        
        // Evening (6pm+)
        if hour >= 18 {
            let titles = ["Evening Wisdom", "Financial Peace", "Reflect"]
            let messages = [
                "Peace of mind comes from knowing where you stand financially.",
                "Reflect on your spending today, \(name). Did it align with your goals?",
                "A penny saved is a penny earned. Good evening, \(name).",
                "Relax, \(name). You're in control of your money.",
                "The best pillow is a clear conscience and a balanced budget.",
                "Did you make your money work for you today, \(name)?",
                "Evening is for relaxing, not stressing about money. Check your tracker.",
                "Wind down and review. You're doing great, \(name)."
            ]
            return (titles.randomElement()!, messages.randomElement()!)
        }
        
        // General Day (Tips, Quotes, Humor)
        let titles = ["Money Tip", "Did You Know?", "Stay Focused", "Financial Fact", "Smart Move"]
        let messages = [
            "A budget is telling your money where to go instead of wondering where it went.",
            "Small leaks sink great ships. Watch those small expenses, \(name)!",
            "Do not save what is left after spending, but spend what is left after saving.",
            "Financial freedom is available to those who learn about it and work for it.",
            "It's not your salary that makes you rich, it's your spending habits.",
            "Beware of little expenses; a small leak will sink a great ship.",
            "The art is not in making money, but in keeping it.",
            "Every transaction counts towards your future, \(name).",
            "Invest in yourself by tracking your money.",
            "Buying things you don't need with money you don't have to impress people you don't like? Skip it.",
            "Compound interest is the eighth wonder of the world. He who understands it, earns it.",
            "Price is what you pay. Value is what you get. Look for value, \(name).",
            "Don't go broke trying to look rich, \(name).",
            "Savings today = Security tomorrow.",
            "Rule No. 1: Never lose money. Rule No. 2: Never forget Rule No. 1.",
            "You can have anything you want, but not everything you want. Choose wisely, \(name).",
            "Rich people stay rich by living like they're poor. Poor people stay poor by living like they're rich."
        ]
        
        return (titles.randomElement()!, messages.randomElement()!)
    }
}
