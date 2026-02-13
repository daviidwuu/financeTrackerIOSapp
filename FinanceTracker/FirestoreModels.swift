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
        
        // Travel / Currency Support
        var currencyCode: String? = nil // e.g., "USD", "JPY"
        var exchangeRate: Double? = nil // e.g., 100.0 (1 Main = 100 Travel) or 0.01
        var originalAmount: Double? = nil // Amount in original currency
        
        // Splits
        var splits: [Split]? = nil
        
        // Location
        var latitude: Double? = nil
        var longitude: Double? = nil
        var locationName: String? = nil
        
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
            case currencyCode
            case exchangeRate
            case originalAmount
            case splits
            case latitude
            case longitude
            case locationName
        }
    }
    
    // MARK: - Split Model
    struct Split: Identifiable, Codable {
        var id: String = UUID().uuidString
        var name: String // Friend's name or Guest's name
        var friendId: String? // Linked Friend User ID
        var username: String? // Friend's Username
        var guestId: String? // ✅ NEW: Linked Guest ID
        var isGuest: Bool = false // ✅ NEW: Flag to distinguish guests
        var amount: Double
        var isPaid: Bool
        var isAccepted: Bool = false // ✅ NEW: Tracks if receiver accepted
        var paidDate: Date? // When they paid back
        var incomeTransactionId: String? // Linked ID to the "Income" transaction created when they pay
        var requestId: String? // Linked ID of the SplitRequest sent to the friend
    }

    // MARK: - Guest Model
    struct Guest: Identifiable, Codable {
        @DocumentID var id: String?
        var name: String
        var avatarColor: String // For consistent UI color (random hex)
        var totalOwed: Double // Aggregate debt across all transactions
        var createdAt: Date
        var userId: String // Owner of this guest record
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case avatarColor
            case totalOwed
            case createdAt
            case userId
        }
    }

    // MARK: - FriendRequest Model
    struct FriendRequest: Identifiable, Codable {
        @DocumentID var id: String?
        var fromUid: String
        var toUid: String
        var status: String // "pending", "accepted", "declined"
        var fromName: String? // ✅ NEW: For UI display
        var fromUsername: String? // ✅ NEW: For UI display
        var createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case fromUid
            case toUid
            case status
            case fromName
            case fromUsername
            case createdAt
        }
    }

    // MARK: - GroupInvitation Model
    struct GroupInvitation: Identifiable, Codable {
        @DocumentID var id: String?
        var groupId: String
        var groupName: String // Denormalized for UI
        var fromUid: String
        var toUid: String
        var status: String // "pending", "accepted", "declined", "blocked_by_friendship"
        var dependencyId: String? // Links to blocking friend_request
        var createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case groupId
            case groupName
            case fromUid
            case toUid
            case status
            case dependencyId
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
            // 2. Filter transactions and calculate Net Spend
            let netDiff = transactions
                .filter { transaction in
                    // Match category
                    // Include both Expenses (negative) and Reimbursements (positive)
                    // Exclude "Income" category explicitly if needed, but usually budgeting is for specific categories
                    guard transaction.subtitle == category else { return false }
                    return transaction.date >= startDate && transaction.date < endDate
                }
                .reduce(0) { $0 + $1.amount }
            
            // If netDiff is -25 (Net Expense), Spent is 25.
            // If netDiff is +10 (Net Profit), Spent is 0.
            let spent = netDiff < 0 ? abs(netDiff) : 0
                
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
    // MARK: - Group Model
    struct Group: Identifiable, Codable {
        @DocumentID var id: String?
        var name: String
        var normalizedName: String? // ✅ NEW: For duplicate detection
        var members: [String] // ✅ RENAMED from memberIds
        var createdBy: String // ✅ NEW: Track creator
        var icon: String
        var color: String // ✅ RENAMED from colorHex
        var createdAt: Date
        var updatedAt: Date? // ✅ NEW: Track modifications
        var defaultCurrency: String? // ✅ NEW: Master currency for the group
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case normalizedName
            case members
            case createdBy
            case icon
            case color
            case createdAt
            case updatedAt
            case defaultCurrency
        }
        
        func isMember(_ uid: String) -> Bool {
            return members.contains(uid)
        }
    }

    // MARK: - GroupTransaction Model
    struct GroupTransaction: Identifiable, Codable {
        @DocumentID var id: String?
        var title: String
        var amount: Double
        var payerId: String
        var payerName: String
        var date: Date
        var type: String // "expense" or "income" (reimbursement)
        var currencyCode: String?
        var note: String? // ✅ NEW: Separated from title
        var category: String? // ✅ NEW: For icon lookup
        var icon: String? // ✅ NEW
        var colorHex: String? // ✅ NEW
        var originalTransactionId: String? // Linked to the user's private transaction
        
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case amount
            case payerId
            case payerName
            case date
            case type
            case currencyCode
            case note
            case category
            case originalTransactionId
        }
    }

    // MARK: - SplitRequest Model
    struct SplitRequest: Identifiable, Codable {
        @DocumentID var id: String?
        var transactionId: String
        var groupId: String? // ✅ NEW: Link to group
        var fromUid: String // ✅ RENAMED from requesterId
        var toUid: String // ✅ NEW: Explicit receiver
        var fromName: String? // Denormalized sender name
        var toName: String? // ✅ NEW: Denormalized receiver name (Friend or Guest)
        var amount: Double
        var currency: String? // ✅ NEW: Multi-currency support
        var note: String?
        var status: RequestStatus // ✅ CHANGED to enum
        var dependencyId: String? // ✅ NEW: Links to blocking document
        var lastNudgedAt: Date? // ✅ NEW: For nudge feature
        var createdAt: Date
        
        enum RequestStatus: String, Codable {
            case pending
            case accepted
            case declined
            case paid
            case blocked_by_group
            case blocked_by_friendship
            case unknown
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let rawValue = try container.decode(String.self)
                self = RequestStatus(rawValue: rawValue) ?? .unknown
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case id
            case transactionId
            case groupId
            case fromUid
            case toUid
            case fromName
            case toName
            case amount
            case currency
            case note
            case status
            case dependencyId
            case lastNudgedAt
            case createdAt
        }
    }
    
    // MARK: - Friend Model
    struct Friend: Identifiable, Codable {
        @DocumentID var id: String? // The Friend's User ID
        var username: String
        var name: String // Display Name
        var email: String? // Optional
        var addedAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case username
            case name
            case email
            case addedAt
        }
    }
    // MARK: - User Profile Model
    struct UserProfile: Codable {
        @DocumentID var id: String?
        var name: String
        var email: String
        var username: String
        var createdAt: Date
        
        // Gamification
        var points: Int? = 0
        var completedMissionIds: [String]? = []
        var streakCount: Int? = 1
        var lastVisitDate: Date?
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case email
            case username
            case createdAt
            case points
            case completedMissionIds
            case streakCount
            case lastVisitDate
        }
    }
    
    // MARK: - Rewards System
    struct Reward: Identifiable, Codable, Equatable {
        var id: String
        var title: String
        var cost: Int
        var icon: String // SF Symbol
        var partnerName: String
        var description: String
        var colorHex: String
    }
    
    struct Redemption: Identifiable, Codable {
        var id: String = UUID().uuidString
        var rewardId: String
        var rewardTitle: String
        var rewardIcon: String
        var cost: Int
        var date: Date
        var code: String // Unique redemption code
    }
}
