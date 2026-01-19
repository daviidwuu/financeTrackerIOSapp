import AppIntents

struct FinanceTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogTransactionIntent(),
            phrases: [
                "Log Transaction in \(.applicationName)",
                "Add Expense to \(.applicationName)",
                "New Transaction in \(.applicationName)",
                "Log Expense in \(.applicationName)",
                "Track Spending in \(.applicationName)"
            ],
            shortTitle: "Log Transaction",
            systemImageName: "plus.circle.fill"
        )
    }
}
