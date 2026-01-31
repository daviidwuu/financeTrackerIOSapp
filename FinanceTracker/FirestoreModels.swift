import Foundation
import FirebaseFirestore

enum FirestoreModels {


    // MARK: - Transaction Model
    struct Transaction: Identifiable, Codable {
        @DocumentID var id: String?
        var title: String
        var subtitle: String? // category name
        var amount: Double
        var date: Date
        var icon: String
        var colorHex: String
        var note: String?
        var type: String // "expense" or "income"
        var source: String? // "shortcuts", "manual", etc.
        var userId: String
        var createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case subtitle
            case amount
            case date
            case icon
            case colorHex
            case note
            case type
            case source
            case userId
            case createdAt
        }
    }

    // MARK: - CategoryBudget Model
    struct CategoryBudget: Identifiable, Codable {
        @DocumentID var id: String?
        var category: String
        var totalAmount: Double
        var icon: String
        var colorHex: String
        var frequency: String // "Monthly", "Weekly", etc.
        var type: String? = "expense" // Added type
        var userId: String
        var monthStartDate: Date
        var createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case category
            case totalAmount
            case icon
            case colorHex
            case frequency
            case type
            case userId
            case monthStartDate
            case createdAt
        }
        
        // Computed property for remaining amount (calculated from transactions)
        func remainingAmount(transactions: [Transaction]) -> Double {
            let calendar = Calendar.current
            let now = Date()
            
            // 1. Identify valid date range based on frequency
            let startDate: Date
            let endDate: Date
            
            switch frequency {
            case "Weekly":
                // Start of current week (assuming Sunday start)
                startDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                endDate = calendar.date(byAdding: .day, value: 7, to: startDate)!
            case "Bi-Weekly":
                // Start of current 2-week period (Naive implementation: Assume aligned with weeks)
                // A better approach would be to calculate from a fixed epoch, but for now we'll match weekly start
                // and check parity, or just look at last 14 days? 
                // Let's stick to: Current Week + Previous Week? No, that shifts.
                // Standard approach: Start of year -> chunk by 2 weeks.
                let weekOfYear = calendar.component(.weekOfYear, from: now)
                let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                
                if weekOfYear % 2 == 0 {
                   // Even week: This + Next is a pair? Or Prev + This? 
                   // Let's align with: Week 1-2, 3-4, etc.
                   // If current is 4 (even), start is week 3.
                   startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek)!
                } else {
                   // Odd week: This + Next
                   startDate = startOfWeek
                }
                endDate = calendar.date(byAdding: .day, value: 14, to: startDate)!
                
            case "Yearly":
                startDate = calendar.date(from: calendar.dateComponents([.year], from: now))!
                endDate = calendar.date(byAdding: .year, value: 1, to: startDate)!
                
            default: // "Monthly"
                // Dynamically calculate the current month's range
                startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                endDate = calendar.date(byAdding: .month, value: 1, to: startDate)!
            }
            
            // 2. Filter transactions
            let spent = transactions
                .filter { transaction in
                    guard transaction.subtitle == category && transaction.type == "expense" else { return false }
                    return transaction.date >= startDate && transaction.date < endDate
                }
                .reduce(0) { $0 + abs($1.amount) }
                
            return totalAmount - spent
        }
    }

    // MARK: - SavingGoal Model
    struct SavingGoal: Identifiable, Codable {
        @DocumentID var id: String?
        var name: String
        var targetAmount: Double
        var currentAmount: Double
        var targetDate: Date
        var icon: String
        var colorHex: String
        var sortOrder: Int? // Added for reordering
        var userId: String
        var createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case targetAmount
            case currentAmount
            case targetDate
            case icon
            case colorHex
            case sortOrder
            case userId
            case createdAt
        }
    }

    // MARK: - RecurringTransaction Model
    struct RecurringTransaction: Identifiable, Codable {
        @DocumentID var id: String?
        var name: String
        var amount: Double
        var frequency: String // "Daily", "Weekly", "Monthly"
        var startDate: Date
        var icon: String
        var colorHex: String
        var note: String?
        var type: String? = "expense" // "expense" or "income"
        var userId: String
        var createdAt: Date
        var lastProcessedDate: Date? // For tracking auto-execution
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case amount
            case frequency
            case startDate
            case icon
            case colorHex
            case note
            case type
            case userId
            case createdAt
            case lastProcessedDate
        }
    }
}
