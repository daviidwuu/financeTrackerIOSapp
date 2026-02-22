import Foundation
import FirebaseFirestore

enum FirestoreModels {



    
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
        var status: String? = nil // ✅ NEW: "pending", "accepted", "declined", "paid"
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
        func remainingAmount(transactions: [TransactionModel]) -> Double {
            return totalAmount - spentAmount(transactions: transactions)
        }
        
        // Calculate amount spent in the current period
        func spentAmount(transactions: [TransactionModel]) -> Double {
            // Use centralized calculator for consistent windows anchored to monthStartDate
            let calculator = BudgetPeriodCalculator(calendar: Calendar.current, anchor: monthStartDate)
            let window = calculator.window(frequency: frequency)
            
            // Filter transactions and calculate Net Spend
            let netDiff = transactions
                .filter { transaction in
                    // Match category
                    // Include both Expenses (negative) and Reimbursements (positive)
                    guard transaction.subtitle == category else { return false }
                    return transaction.date >= window.start && transaction.date < window.end
                }
                .reduce(0) { $0 + $1.amount }
            
            // If netDiff is -25 (Net Expense), Spent is 25.
            // If netDiff is +10 (Net Profit), Spent is 0.
            return netDiff < 0 ? abs(netDiff) : 0
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

    struct EditRecord: Codable, Identifiable {
        var id: String = UUID().uuidString
        var date: Date
        var editorId: String
        var editorName: String
        var field: String
        var oldValue: String
        var newValue: String
    }

    struct TransactionModel: Codable, Identifiable {
        @DocumentID var id: String?
        var userId: String
        var title: String
        var subtitle: String? // Category
        var amount: Double
        var date: Date
        var type: String // "income" or "expense"
        var createdAt: Date
        var icon: String?
        var colorHex: String?
        var note: String?
        var source: String? // ✅ Restored field
        
        // Location
        var latitude: Double?
        var longitude: Double?
        var locationName: String?
        
        // Splits
        var splits: [Split]?
        var originalAmount: Double? // Before split
        var currencyCode: String?
        var exchangeRate: Double? // ✅ Restored field
        
        var editHistory: [EditRecord]? // ✅ NEW: Track changes

        init(
            id: String? = nil,
            userId: String,
            title: String,
            subtitle: String? = nil,
            amount: Double,
            date: Date,
            type: String,
            createdAt: Date,
            icon: String? = nil,
            colorHex: String? = nil,
            note: String? = nil,
            source: String? = nil,
            latitude: Double? = nil,
            longitude: Double? = nil,
            locationName: String? = nil,
            splits: [Split]? = nil,
            originalAmount: Double? = nil,
            currencyCode: String? = nil,
            exchangeRate: Double? = nil,
            editHistory: [EditRecord]? = nil
        ) {
            self.id = id
            self.userId = userId
            self.title = title
            self.subtitle = subtitle
            self.amount = amount
            self.date = date
            self.type = type
            self.createdAt = createdAt
            self.icon = icon
            self.colorHex = colorHex
            self.note = note
            self.source = source
            self.latitude = latitude
            self.longitude = longitude
            self.locationName = locationName
            self.splits = splits
            self.originalAmount = originalAmount
            self.currencyCode = currencyCode
            self.exchangeRate = exchangeRate
            self.editHistory = editHistory
        }

        enum CodingKeys: String, CodingKey {
            case id
            case userId
            case title
            case subtitle
            case amount
            case date
            case type
            case createdAt
            case icon
            case colorHex
            case note
            case source
            case latitude
            case longitude
            case locationName
            case splits
            case originalAmount
            case currencyCode
            case exchangeRate
            case editHistory
        }
    }
    // MARK: - Group Model
    struct Group: Identifiable, Codable, Hashable {
        @DocumentID var id: String?
        var name: String
        var normalizedName: String? // ✅ NEW: For duplicate detection
        var members: [String] // ✅ RENAMED from memberIds
        var memberNames: [String: String]? // ✅ NEW: Denormalized map [UID: Name]
        var createdBy: String // ✅ NEW: Track creator
        var icon: String
        var color: String // ✅ RENAMED from colorHex
        var createdAt: Date
        var updatedAt: Date? // ✅ NEW: Track modifications
        var defaultCurrency: String? // ✅ NEW: Master currency for the group
        var deletionStatus: String? // ✅ NEW: "requested" or nil
        var memberActions: [String: String]? // ✅ NEW: Map [UID: "keep" | "delete"]
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case normalizedName
            case members
            case memberNames
            case createdBy
            case icon
            case color
            case createdAt
            case updatedAt
            case defaultCurrency
            case deletionStatus
            case memberActions
        }
        
        func isMember(_ uid: String) -> Bool {
            return members.contains(uid)
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: Group, rhs: Group) -> Bool {
            return lhs.id == rhs.id
        }
    }

    // MARK: - GroupTransaction Model
    struct GroupTransaction: Identifiable, Codable {
        @DocumentID var id: String?
        var title: String
        var amount: Double
        var payerId: String
        var payerName: String
        var receiverId: String? // ✅ NEW: For settlement logic
        var receiverName: String? // ✅ NEW: For settlement details
        var date: Date
        var type: String // "expense" or "income" (reimbursement)
        var currencyCode: String?
        var note: String? // ✅ NEW: Separated from title
        var category: String? // ✅ NEW: For icon lookup
        var icon: String? // ✅ NEW
        var colorHex: String? // ✅ NEW
        var originalTransactionId: String? // Linked to the user's private transaction
        var originalAmount: Double? // ✅ NEW: Foreign currency amount
        var exchangeRate: Double? // ✅ NEW: Exchange rate used
        var latitude: Double? // ✅ NEW: Maps location support
        var longitude: Double? // ✅ NEW: Maps location support
        var involvedUserStatuses: [String: String]? // ✅ NEW: Maps userId to RequestStatus string
        var editHistory: [EditRecord]? // ✅ NEW: Track changes
        
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case amount
            case payerId
            case payerName
            case receiverId
            case receiverName
            case date
            case type
            case currencyCode
            case note
            case category
            case icon
            case colorHex
            case originalTransactionId
            case originalAmount
            case exchangeRate
            case latitude
            case longitude
            case involvedUserStatuses
            case editHistory
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
        var hiddenFor: [String]? // ✅ NEW: User IDs who have hidden this split from their view
        var originalTotalAmount: Double? // ✅ NEW: Full pre-split expense total
        var isGuest: Bool? // FIX 3.5: Flag to distinguish guest split requests
        var isSettlement: Bool? // Flag to distinguish settlement requests from regular splits
        var latitude: Double? // ✅ NEW: Maps location support
        var longitude: Double? // ✅ NEW: Maps location support
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
            case hiddenFor
            case originalTotalAmount
            case isGuest
            case isSettlement
            case latitude
            case longitude
            case createdAt
        }
    }
    
    // MARK: - Friend Model
    struct Friend: Identifiable, Codable, Hashable {
        @DocumentID var id: String? // The Friend's User ID
        var username: String? // Made optional to handle decoding failures
        var name: String // Display Name
        var email: String? // Optional
        var avatarColor: String? // ✅ NEW: For consistent UI color
        var addedAt: Date? // Made optional
        
        enum CodingKeys: String, CodingKey {
            case id
            case username
            case name
            case email
            case avatarColor
            case addedAt
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: Friend, rhs: Friend) -> Bool {
            return lhs.id == rhs.id
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
