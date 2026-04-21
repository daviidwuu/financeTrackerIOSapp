import Foundation
import FirebaseFirestore

extension FirestoreModels {

    // MARK: - CategoryBudget Model
    struct CategoryBudget: Identifiable, Codable {
        @DocumentID var id: String?
        var category: String
        var totalAmount: Double
        var icon: String
        var colorHex: String
        var frequency: String // "Monthly", "Weekly", etc.
        var type: String? // Removed inline default to allow synthesize `decodeIfPresent`
        var userId: String
        var monthStartDate: Date
        var createdAt: Date

        // Backend Aggregation Fields (Must exist to satisfy CodingKeys if present in DB)
        var currentPeriodSpent: Double?
        var lastAggregatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, category, totalAmount, icon, colorHex, frequency, type, userId
            case monthStartDate, createdAt, currentPeriodSpent, lastAggregatedAt
        }

        init(
            id: String? = nil,
            category: String,
            totalAmount: Double,
            icon: String,
            colorHex: String,
            frequency: String,
            type: String? = nil,
            userId: String,
            monthStartDate: Date,
            createdAt: Date = Date(),
            currentPeriodSpent: Double? = nil,
            lastAggregatedAt: Date? = nil
        ) {
            self.id = id
            self.category = category
            self.totalAmount = totalAmount
            self.icon = icon
            self.colorHex = colorHex
            self.frequency = frequency
            self.type = type
            self.userId = userId
            self.monthStartDate = monthStartDate
            self.createdAt = createdAt
            self.currentPeriodSpent = currentPeriodSpent
            self.lastAggregatedAt = lastAggregatedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
            category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Unknown"
            totalAmount = try container.decodeIfPresent(Double.self, forKey: .totalAmount) ?? 0.0
            icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "tag"
            colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#888888"
            frequency = try container.decodeIfPresent(String.self, forKey: .frequency) ?? "Monthly"
            type = try container.decodeIfPresent(String.self, forKey: .type)
            userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
            monthStartDate = try container.decodeIfPresent(Date.self, forKey: .monthStartDate) ?? Date()
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
            currentPeriodSpent = try container.decodeIfPresent(Double.self, forKey: .currentPeriodSpent)
            lastAggregatedAt = try container.decodeIfPresent(Date.self, forKey: .lastAggregatedAt)
        }

        // Computed property for remaining amount (calculated from transactions)
        func remainingAmount(transactions: [TransactionModel]) -> Double {
            return DecimalPrecision.subtract(totalAmount, spentAmount(transactions: transactions))
        }

        /// Filters transactions matching this budget's category within the current period.
        private func matchingTransactions(from transactions: [TransactionModel]) -> [TransactionModel] {
            let calculator = BudgetPeriodCalculator(calendar: Calendar.current, anchor: monthStartDate)
            let window = calculator.window(frequency: frequency)

            return transactions.filter { transaction in
                if let txCategoryId = transaction.categoryId, txCategoryId == id {
                    // categoryId matches this budget's document ID
                } else if let subtitle = transaction.subtitle, subtitle == category {
                    // Legacy fallback: match by category name (pre-migration data)
                } else {
                    return false
                }
                return transaction.date >= window.start && transaction.date < window.end
            }
        }

        /// FIX #2: Net spent (expenses minus reimbursements) — used for budget remaining calculation.
        func spentAmount(transactions: [TransactionModel]) -> Double {
            let matched = matchingTransactions(from: transactions)
            let netDiff = DecimalPrecision.sum(matched.map { $0.amount })
            return netDiff < 0 ? abs(netDiff) : 0
        }

        /// FIX #2: Gross spent — actual total expenses regardless of reimbursements.
        func grossSpentAmount(transactions: [TransactionModel]) -> Double {
            let matched = matchingTransactions(from: transactions)
            return DecimalPrecision.sum(
                matched.filter { $0.amount < 0 }.map { abs($0.amount) }
            )
        }

        /// FIX #2: Total reimbursements received in this category.
        func reimbursedAmount(transactions: [TransactionModel]) -> Double {
            let matched = matchingTransactions(from: transactions)
            return DecimalPrecision.sum(
                matched.filter { $0.amount > 0 }.map { $0.amount }
            )
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
            case id, name, targetAmount, currentAmount, targetDate, icon, colorHex
            case sortOrder, userId, createdAt
        }

        init(
            id: String? = nil,
            name: String,
            targetAmount: Double,
            currentAmount: Double = 0,
            targetDate: Date,
            icon: String,
            colorHex: String,
            sortOrder: Int? = nil,
            userId: String,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.name = name
            self.targetAmount = targetAmount
            self.currentAmount = currentAmount
            self.targetDate = targetDate
            self.icon = icon
            self.colorHex = colorHex
            self.sortOrder = sortOrder
            self.userId = userId
            self.createdAt = createdAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unnamed Goal"
            targetAmount = try container.decodeIfPresent(Double.self, forKey: .targetAmount) ?? 0.0
            currentAmount = try container.decodeIfPresent(Double.self, forKey: .currentAmount) ?? 0.0
            targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate) ?? Date()
            icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "star"
            colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#888888"
            sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)
            userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        }
    }
}
