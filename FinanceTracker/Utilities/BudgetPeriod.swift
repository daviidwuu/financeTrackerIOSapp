import Foundation

struct PeriodWindow {
    let start: Date
    let end: Date
}

struct BudgetPeriodCalculator {
    let calendar: Calendar
    let anchor: Date // Typically monthStartDate from the budget model

    /// Calculates the start and end dates for the current budget period based on frequency.
    /// - Parameters:
    ///   - frequency: "Weekly", "Bi-Weekly", "Monthly", or "Yearly"
    ///   - now: The date to calculate the period for (default is current date)
    /// - Returns: A PeriodWindow containing the start (inclusive) and end (exclusive) dates.
    func window(frequency: String, now: Date = Date()) -> PeriodWindow {
        switch frequency {
        case "Weekly":
            // Anchor to the start of the week containing the anchor date
            let anchorWeekStart = startOfWeek(containing: anchor)
            let nowWeekStart = startOfWeek(containing: now)
            
            // Calculate number of weeks between anchor and now
            // This ensures we stay aligned to the anchor's day-of-week cycle
            let components = calendar.dateComponents([.weekOfYear], from: anchorWeekStart, to: nowWeekStart)
            let weeks = components.weekOfYear ?? 0
            
            let start = calendar.date(byAdding: .weekOfYear, value: weeks, to: anchorWeekStart)!
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return PeriodWindow(start: start, end: end)
            
        case "Bi-Weekly":
            // Anchor to the start of the week containing the anchor date
            let anchorWeekStart = startOfWeek(containing: anchor)
            let nowWeekStart = startOfWeek(containing: now)
            
            // Calculate number of weeks between anchor and now
            let components = calendar.dateComponents([.weekOfYear], from: anchorWeekStart, to: nowWeekStart)
            let weeks = components.weekOfYear ?? 0
            
            // Calculate the start of the current 2-week block
            // Use integer division to find which 2-week block we are in
            // (e.g., weeks 0, 1 -> block 0; weeks 2, 3 -> block 1)
            // Note: Use floor for negative weeks if anchor is in future (though unlikely for budgets)
            let periods = Int(floor(Double(weeks) / 2.0))
            
            let start = calendar.date(byAdding: .weekOfYear, value: periods * 2, to: anchorWeekStart)!
            let end = calendar.date(byAdding: .day, value: 14, to: start)!
            return PeriodWindow(start: start, end: end)
            
        case "Yearly":
            let start = alignYear(from: anchor, toCover: now)
            let end = calendar.date(byAdding: .year, value: 1, to: start)!
            return PeriodWindow(start: start, end: end)
            
        default: // "Monthly"
            let start = alignMonthDay(from: anchor, toCover: now)
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return PeriodWindow(start: start, end: end)
        }
    }

    // MARK: - Helper Methods

    private func startOfWeek(containing date: Date) -> Date {
        // Returns the start of the week based on calendar's locale (e.g. Sunday or Monday)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    private func alignMonthDay(from anchor: Date, toCover now: Date) -> Date {
        // Extract the target day of month from anchor (e.g., 15th)
        let anchorDay = calendar.component(.day, from: anchor)
        
        // Get the current month/year
        var components = calendar.dateComponents([.year, .month], from: now)
        let currentMonthStart = calendar.date(from: components)!
        
        // Find the max days in current month to handle edge cases (e.g., 31st in Feb)
        let range = calendar.range(of: .day, in: .month, for: currentMonthStart)
        let maxDays = range?.count ?? 30
        
        // Clamp anchor day to valid range for this month
        components.day = min(anchorDay, maxDays)
        
        var start = calendar.date(from: components)!
        
        // If the calculated start is in the future relative to 'now', 
        // it means we are in the previous month's cycle
        // e.g., Now: Oct 10, Anchor: 15th -> Calculated: Oct 15 (Future) -> Backtrack to Sept 15
        if start > now {
            start = calendar.date(byAdding: .month, value: -1, to: start)!
            
            // Re-clamp for the previous month (e.g., if backtracking from March 31 to Feb)
            let prevMonthRange = calendar.range(of: .day, in: .month, for: start)
            let prevMaxDays = prevMonthRange?.count ?? 30
            
            // We need to preserve the original anchor day logic if possible
            // But 'start' is already set. Let's re-calculate from previous month components
            var prevComponents = calendar.dateComponents([.year, .month], from: start)
            prevComponents.day = min(anchorDay, prevMaxDays)
            start = calendar.date(from: prevComponents)!
        }
        
        return start
    }

    private func alignYear(from anchor: Date, toCover now: Date) -> Date {
        var components = calendar.dateComponents([.month, .day], from: anchor)
        let currentYear = calendar.component(.year, from: now)
        components.year = currentYear
        
        var start = calendar.date(from: components)!
        
        // If start date is in the future, go back one year
        if start > now {
            start = calendar.date(byAdding: .year, value: -1, to: start)!
        }
        
        return start
    }
}
