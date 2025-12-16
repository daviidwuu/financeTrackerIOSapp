import Foundation
import FirebaseFirestore

enum FirestoreModels {
    // MARK: - Category Model
    struct Category: Identifiable, Codable {
        @DocumentID var id: String?
        var name: String
        var icon: String
        var colorHex: String
        var type: String // "expense" or "income"
        var userId: String
        var createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case icon
            case colorHex
            case type
            case userId
            case createdAt
        }
    }

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
            let spent = transactions
                .filter { $0.subtitle == category && $0.type == "expense" }
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
        var userId: String
        var createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case amount
            case frequency
            case startDate
            case icon
            case colorHex
            case note
            case userId
            case createdAt
        }
    }
}
