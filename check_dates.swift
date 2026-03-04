import Foundation

let calendar = Calendar.current
let targetMonth = Date()
let components = calendar.dateComponents([.year, .month], from: targetMonth)
let startOfMonth = calendar.date(from: components)!
let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!

print("startOfMonth: \(startOfMonth) (\(startOfMonth.timeIntervalSince1970))")
print("nextMonth: \(nextMonth) (\(nextMonth.timeIntervalSince1970))")
