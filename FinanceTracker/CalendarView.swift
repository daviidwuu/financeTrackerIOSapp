import SwiftUI

struct CalendarView: View {
    @State private var currentDate = Date()
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    
    let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    @AppStorage("monthlyIncome") private var monthlyIncome = 5000.0
    
    var transactions: [FirestoreModels.Transaction] = []
    
    init(transactions: [FirestoreModels.Transaction] = []) {
        self.transactions = transactions
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
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        let calendar = Calendar.current
                        let dayTransactions = transactions.filter { calendar.isDate($0.date, inSameDayAs: date) }
                        let totalAmount = dayTransactions.reduce(0) { $0 + $1.amount }
                        let isBeforeSignup = isDateBeforeSignup(date)
                        
                        VStack(spacing: 2) {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.caption)
                                .fontWeight(Calendar.current.isDateInToday(date) ? .bold : .regular)
                                .foregroundColor(isBeforeSignup ? .gray.opacity(0.3) : (Calendar.current.isDateInToday(date) ? .white : .primary))
                                .frame(width: 30, height: 30)
                                .background(Calendar.current.isDateInToday(date) ? Color.blue : Color.clear)
                                .clipShape(Circle())
                            
                            if !isBeforeSignup && totalAmount != 0 {
                                Text(totalAmount > 0 ? "+\(Int(totalAmount))" : "\(Int(totalAmount))")
                                    .font(.system(size: 8))
                                    .foregroundColor(totalAmount > 0 ? .green : .red)
                            }
                        }
                    } else {
                        Text("")
                            .frame(width: 30, height: 30)
                    }
                }
            }
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
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentDate)!.count
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // Logic
    func dailyBudget() -> Double {
        let days = Calendar.current.range(of: .day, in: .month, for: currentDate)?.count ?? 30
        return monthlyIncome / Double(days)
    }
    
    func expenses(for date: Date) -> Double {
        let calendar = Calendar.current
        let dailyTransactions = transactions.filter { transaction in
            return calendar.isDate(transaction.date, inSameDayAs: date)
        }
        return dailyTransactions.reduce(0) { $0 + $1.amount }
    }
    
    func dailyStatus(for date: Date) -> (balance: Double, color: Color) {
        let budget = dailyBudget()
        let expense = expenses(for: date)
        let balance = budget - expense
        
        if balance >= 0 {
            return (balance, .green)
        } else {
            return (balance, .red)
        }
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
        guard let signupDate = UserDefaults.standard.object(forKey: "userSignupDate") as? Date else {
            return false // If no signup date, show all dates
        }
        return date < signupDate
    }
}

#Preview {
    CalendarView(transactions: [])
}
