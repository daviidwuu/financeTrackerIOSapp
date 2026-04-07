import SwiftUI

struct CalendarView: View {
    @Binding var currentDate: Date
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @AppStorage("calendarSavingsMode") private var showCashFlow: Bool = true

    let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var transactions: [FirestoreModels.TransactionModel]
    var categories: [FirestoreModels.CategoryBudget]
    var totalBudget: Double
    var signupDate: Date?
    var onDateTapped: ((Date) -> Void)?

    init(currentDate: Binding<Date>, transactions: [FirestoreModels.TransactionModel] = [], categories: [FirestoreModels.CategoryBudget] = [], totalBudget: Double = 0.0, signupDate: Date? = nil, onDateTapped: ((Date) -> Void)? = nil) {
        self._currentDate = currentDate
        self._selectedYear = State(initialValue: Calendar.current.component(.year, from: currentDate.wrappedValue))
        self._selectedMonth = State(initialValue: Calendar.current.component(.month, from: currentDate.wrappedValue))
        self.transactions = transactions
        self.categories = categories
        self.totalBudget = totalBudget
        self.signupDate = signupDate
        self.onDateTapped = onDateTapped
    }
    
    var body: some View {
        let _ = DebugLogger.log("CalendarView loaded with \(transactions.count) transactions.")
        
        VStack(spacing: 20) {
            // Month/Year Selector
            HStack {
                Button(action: { 
                    HapticManager.shared.light()
                    changeMonth(by: -1) 
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(canGoToPreviousMonth() ? .primary : .gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(!canGoToPreviousMonth())
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("\(monthName(from: selectedMonth)) \(String(selectedYear))")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { 
                    HapticManager.shared.light()
                    changeMonth(by: 1) 
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
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
                                
                                let isBeforeSignup = isDateBeforeSignup(date)
                                
                                VStack(spacing: 2) {
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.caption)
                                        .fontWeight(Calendar.current.isDateInToday(date) ? .bold : .regular)
                                        .foregroundColor(isBeforeSignup ? .gray.opacity(0.3) : (Calendar.current.isDateInToday(date) ? Color.backgroundPrimary : .primary))
                                        .frame(width: 30, height: 30)
                                        .background(Calendar.current.isDateInToday(date) ? Color.primary : Color.clear)
                                        .clipShape(Circle())
                                    
                                    if !isBeforeSignup && !isFutureDate(date) && !Calendar.current.isDateInToday(date) {
                                        let status = dailyStatus(for: date)
                                        if status.color != .clear {
                                            Text(status.balance >= 0 ? "+\(Int(status.balance))" : "\(Int(status.balance))")
                                                .font(.system(size: 8))
                                                .foregroundColor(status.color)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !isBeforeSignup {
                                        HapticManager.shared.light()
                                        onDateTapped?(date)
                                    }
                                }
                            } else {
                                Text("")
                                    .frame(width: 30, height: 30)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            
            // Monthly Summary - Dual Mode (Cash Flow or Budget)
            let summary = calculateMonthlySummaryValue()
            let displayValue = summary.value
            let displayLabel = summary.label
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text("$\(Int(displayValue))")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(displayValue >= 0 ? Color.functionalSuccess : Color.functionalError)
                }
                Spacer()
                
                Image(systemName: displayValue >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .font(.title)
                    .foregroundColor(displayValue >= 0 ? .green : .red)
            }
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(AppRadius.medium)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.shared.light()
                withAnimation(.easeInOut(duration: 0.25)) {
                    showCashFlow.toggle()
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.card)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onAppear {
            // Gamification
            GamificationManager.shared.completeMission(id: "insight_master")
            updateSelectedDate() // Ensure state is synced on appear
        }
        .onChange(of: currentDate) { _, newDate in
            updateSelectedDate(from: newDate)
        }

    }
    
    private func updateSelectedDate(from date: Date? = nil) {
        let referenceDate = date ?? currentDate
        selectedYear = Calendar.current.component(.year, from: referenceDate)
        selectedMonth = Calendar.current.component(.month, from: referenceDate)
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
        guard let date = Calendar.current.date(from: components) else { return "Unknown" }
        return formatter.string(from: date)
    }
    
    func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: currentDate),
              let range = calendar.range(of: .day, in: .month, for: currentDate) else {
            return []
        }
        let firstDay = interval.start

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let daysInMonthCount = range.count
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...daysInMonthCount {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        // Pad the array to ensure the last row is full (multiple of 7)
        // This prevents the HStack from centering or distributing the items in the last row
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    // Logic
    func dailyStatus(for date: Date) -> (balance: Double, color: Color) {
        let calendar = Calendar.current
        let dailyTransactions = transactions.filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }

        // If no transactions, no streak (neutral)
        if dailyTransactions.isEmpty {
             return (0.0, .clear)
        }

        let value: Double
        if showCashFlow {
            value = calculateDailyCashFlow(for: date, dailyTransactions: dailyTransactions)
        } else {
            value = calculateDailyBudgetSurplus(for: date, dailyTransactions: dailyTransactions)
        }
        return (value, value >= 0 ? Color.functionalSuccess : Color.functionalError)
    }

    // Budget Mode: Daily Allowance - Expenses + Reimbursements (from splits)
    func calculateDailyBudgetSurplus(for date: Date, dailyTransactions: [FirestoreModels.TransactionModel]) -> Double {
        let calendar = Calendar.current

        guard let range = calendar.range(of: .day, in: .month, for: date) else { return 0 }
        let daysInMonthCount = Double(range.count)
        let dailyAllowance = DecimalPrecision.divide(totalBudget, daysInMonthCount)

        let dailySpent = DecimalPrecision.sum(
            dailyTransactions.filter { $0.type == "expense" }.map { abs($0.amount) }
        )

        let dailyReimbursements = DecimalPrecision.sum(
            dailyTransactions.filter { $0.isReimbursementIncome(categories: categories) }.map { $0.amount }
        )

        return DecimalPrecision.round(dailyAllowance - dailySpent + dailyReimbursements)
    }

    // Cash Flow Mode: All Income - All Expenses
    func calculateDailyCashFlow(for date: Date, dailyTransactions: [FirestoreModels.TransactionModel]) -> Double {
        let dailyIncome = DecimalPrecision.sum(
            dailyTransactions.filter { $0.type == "income" }.map { $0.amount }
        )

        let dailySpent = DecimalPrecision.sum(
            dailyTransactions.filter { $0.type == "expense" }.map { abs($0.amount) }
        )

        return DecimalPrecision.subtract(dailyIncome, dailySpent)
    }

    // MARK: - Monthly Absolute Summary (For Bottom Card)
    func calculateMonthlySummaryValue() -> (value: Double, label: String) {
        let expenses = DecimalPrecision.sum(
            transactions.filter { $0.type == "expense" }.map { abs($0.amount) }
        )

        if showCashFlow {
            // Cash Flow Mode: All Income - All Expenses
            let totalIncome = DecimalPrecision.sum(
                transactions.filter { $0.type == "income" }.map { $0.amount }
            )
            return (DecimalPrecision.subtract(totalIncome, expenses), "Net Cash Flow")
        } else {
            // Budget Mode: Prorated budget (completed days only) - Expenses + Reimbursements
            let calendar = Calendar.current
            guard let range = calendar.range(of: .day, in: .month, for: currentDate) else {
                return (0, "Under Budget")
            }
            let daysInMonth = Double(range.count)
            let dailyAllowance = DecimalPrecision.divide(totalBudget, daysInMonth)

            // FIX #1: Include today in completed days to match savings pool calculation
            let today = Date()
            let isCurrentMonth = calendar.isDate(currentDate, equalTo: today, toGranularity: .month)
            let completedDays: Double
            if isCurrentMonth {
                completedDays = Double(calendar.component(.day, from: today))
            } else if currentDate < today {
                completedDays = daysInMonth
            } else {
                completedDays = 0
            }

            let proratedBudget = DecimalPrecision.multiply(dailyAllowance, completedDays)
            let reimbursements = DecimalPrecision.sum(
                transactions.filter { $0.isReimbursementIncome(categories: categories) }.map { $0.amount }
            )
            return (DecimalPrecision.round(proratedBudget - expenses + reimbursements), "Under Budget")
        }
    }
    
    // Check if date is in the future
    func isFutureDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
    }
    
    // Check if can navigate to previous month based on signup date
    func canGoToPreviousMonth() -> Bool {
        let targetSignupDate: Date
        
        if let propDate = self.signupDate {
            targetSignupDate = propDate
        } else {
            return true // Fallback to allowing navigation
        }
        
        let calendar = Calendar.current
        guard let currentMonth = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth)),
              let signupMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: targetSignupDate)) else {
            return true // Allow navigation if date construction fails
        }

        return currentMonth > signupMonth
    }
    
    // Check if date is before user signup
    func isDateBeforeSignup(_ date: Date) -> Bool {
        let calendar = Calendar.current
        
        guard let targetSignupDate = self.signupDate else {
            return false // Show all if no indicator found
        }
        
        return calendar.startOfDay(for: date) < calendar.startOfDay(for: targetSignupDate)
    }
}

#Preview {
    CalendarView(currentDate: .constant(Date()), transactions: [], categories: [], totalBudget: 5000.0)
}

// Helper extension for chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
