import SwiftUI

struct CalendarView: View {
    @State private var currentDate = Date()
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    
    let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var transactions: [FirestoreModels.Transaction] = []
    var totalBudget: Double = 0.0
    var monthlyIncome: Double = 0.0
    
    init(transactions: [FirestoreModels.Transaction] = [], totalBudget: Double = 0.0, monthlyIncome: Double = 0.0) {
        self.transactions = transactions
        self.totalBudget = totalBudget
        self.monthlyIncome = monthlyIncome
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Month/Year Selector
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(canGoToPreviousMonth() ? .primary : .gray.opacity(0.3))
                }
                .disabled(!canGoToPreviousMonth())
                
                Spacer()
                
                Text("\(monthName(from: selectedMonth)) \(String(selectedYear))")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            
            // Days of Week
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar Grid
            VStack(spacing: 15) {
                let days = daysInMonth()
                let weeks = days.chunked(into: 7)
                
                ForEach(weeks.indices, id: \.self) { weekIndex in
                    HStack {
                        ForEach(weeks[weekIndex].indices, id: \.self) { dayIndex in
                            let date = weeks[weekIndex][dayIndex]
                            if let date = date {
                                let calendar = Calendar.current
                                let dayTransactions = transactions.filter { calendar.isDate($0.date, inSameDayAs: date) }
                                let dayExpenses = dayTransactions.filter { $0.type == "expense" }.reduce(0) { $0 + abs($1.amount) }
                                let isBeforeSignup = isDateBeforeSignup(date)
                                
                                VStack(spacing: 2) {
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.caption)
                                        .fontWeight(Calendar.current.isDateInToday(date) ? .bold : .regular)
                                        .foregroundColor(isBeforeSignup ? .gray.opacity(0.3) : (Calendar.current.isDateInToday(date) ? .white : .primary))
                                        .frame(width: 30, height: 30)
                                        .background(Calendar.current.isDateInToday(date) ? Color.blue : Color.clear)
                                        .clipShape(Circle())
                                    
                                    if !isBeforeSignup && !isFutureDate(date) {
                                        let surplus = calculateSurplus(for: date)
                                        Text(surplus >= 0 ? "+\(Int(surplus))" : "\(Int(surplus))")
                                            .font(.system(size: 8))
                                            .foregroundColor(surplus >= 0 ? .green : .red)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Text("")
                                    .frame(width: 30, height: 30)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            
            // Monthly Summary
            let monthlySaved = calculateMonthlySaving()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved This Month")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text("$\(Int(monthlySaved))")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(monthlySaved >= 0 ? .green : .red)
                }
                Spacer()
                
                Image(systemName: monthlySaved >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .font(.title)
                    .foregroundColor(monthlySaved >= 0 ? .green : .red)
            }
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(15)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // Helpers
    func changeMonth(by value: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = newDate
            selectedYear = calendar.component(.year, from: newDate)
            selectedMonth = calendar.component(.month, from: newDate)
        }
    }
    
    func monthName(from month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let components = DateComponents(month: month)
        return formatter.string(from: Calendar.current.date(from: components)!)
    }
    
    func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: currentDate)!
        let firstDay = interval.start
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let daysInMonthCount = calendar.range(of: .day, in: .month, for: currentDate)!.count
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...daysInMonthCount {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // Logic
    func dailyBudget() -> Double {
        let days = Calendar.current.range(of: .day, in: .month, for: currentDate)?.count ?? 30
        // Use totalBudget if provided, otherwise fallback to monthlyIncome (legacy)
        let baseAmount = totalBudget > 0 ? totalBudget : 5000.0 
        return baseAmount / Double(days)
    }
    
    func dailyStatus(for date: Date) -> (balance: Double, color: Color) {
        let surplus = calculateSurplus(for: date)
        return (surplus, surplus >= 0 ? .green : .red)
    }
    
    func calculateSurplus(for date: Date) -> Double {
        let calendar = Calendar.current
        
        // 1. Get the number of days in this specific month
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return 0 }
        let daysInMonthCount = Double(range.count)
        
        // 2. Determine the Daily Allowance (The "Grind" Budget)
        let dailyAllowance = totalBudget / daysInMonthCount
        
        // 3. Calculate "Manual" Flow for this specific day
        let dailyTransactions = transactions.filter { 
            calendar.isDate($0.date, inSameDayAs: date) 
        }
        
        let dailySpent = dailyTransactions
            .filter { $0.type == "expense" }
            .reduce(0) { $0 + abs($1.amount) }
            
        let dailyManualIncome = dailyTransactions
            .filter { $0.type == "income" } // One-off gigs, sales
            .reduce(0) { $0 + $1.amount }
            
        // 4. Base Surplus (The Simulation Result)
        var surplus = dailyAllowance - dailySpent + dailyManualIncome
        
        // 5. The Reconciliation (The Vault Reveal)
        // Check if 'date' is the last day of the month
        if let monthInterval = calendar.dateInterval(of: .month, for: date),
           let endOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
           calendar.isDate(date, inSameDayAs: endOfMonth) {
            
            // Add the unallocated Recurring Income
            // (Total Salary - The Total Budget you already distributed via dailyAllowance)
            let vaultSavings = monthlyIncome - totalBudget
            surplus += vaultSavings
        }
        
        return surplus
    }
    
    func calculateMonthlySaving() -> Double {
        let days = daysInMonth().compactMap { $0 }
        var totalSaved = 0.0
        
        for date in days {
            if !isDateBeforeSignup(date) && !isFutureDate(date) {
                let status = dailyStatus(for: date)
                totalSaved += status.balance
            }
        }
        
        return totalSaved
    }
    
    // Check if date is in the future
    func isFutureDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
    }
    
    func calculateMonthlySummary() -> (saved: Double, overspent: Double) {
        var totalSaved = 0.0
        var totalOverspent = 0.0
        
        let days = daysInMonth().compactMap { $0 }
        
        for date in days {
            let status = dailyStatus(for: date)
            if status.balance >= 0 {
                totalSaved += status.balance
            } else {
                totalOverspent += abs(status.balance)
            }
        }
        
        return (totalSaved, totalOverspent)
    }
    
    // Check if can navigate to previous month based on signup date
    func canGoToPreviousMonth() -> Bool {
        guard let signupDate = UserDefaults.standard.object(forKey: "userSignupDate") as? Date else {
            return true // If no signup date, allow navigation
        }
        
        let calendar = Calendar.current
        let currentMonth = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth))!
        let signupMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: signupDate))!
        
        return currentMonth > signupMonth
    }
    
    // Check if date is before user signup
    func isDateBeforeSignup(_ date: Date) -> Bool {
        let calendar = Calendar.current
        
        // Find signup date: UserDefaults or fallback to first transaction
        let signupDate: Date
        if let savedDate = UserDefaults.standard.object(forKey: "userSignupDate") as? Date {
            signupDate = savedDate
        } else if let firstTransaction = transactions.last?.date {
            signupDate = firstTransaction
        } else {
            return false // Show all if no indicator found
        }
        
        return calendar.startOfDay(for: date) < calendar.startOfDay(for: signupDate)
    }
}

#Preview {
    CalendarView(transactions: [], totalBudget: 5000.0, monthlyIncome: 6000.0)
}

// Helper extension for chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
