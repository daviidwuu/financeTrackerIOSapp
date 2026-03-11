import Foundation
import FirebaseFirestore

enum FirestoreModels {



    
    // MARK: - Split Status Enum
    enum SplitStatus: String, Codable {
        case pending
        case accepted
        case declined
        case paid
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
        var splitStatus: SplitStatus = .pending // Single source of truth
        var paidDate: Date? // When they paid back
        var incomeTransactionId: String? // Linked ID to the "Income" transaction created when they pay
        var requestId: String? // Linked ID of the SplitRequest sent to the friend

        // MARK: - Computed legacy accessors (backward compatibility)
        var isPaid: Bool {
            get { splitStatus == .paid }
            set { if newValue { splitStatus = .paid } else if splitStatus == .paid { splitStatus = .pending } }
        }

        var isAccepted: Bool {
            get { splitStatus == .accepted || splitStatus == .paid }
            set { if newValue && splitStatus == .pending { splitStatus = .accepted } }
        }

        var status: String? {
            get { splitStatus.rawValue }
            set {
                if let raw = newValue, let parsed = SplitStatus(rawValue: raw) {
                    splitStatus = parsed
                }
            }
        }

        // MARK: - Custom Codable (reads legacy isPaid/isAccepted/status fields from old documents)
        enum CodingKeys: String, CodingKey {
            case id, name, friendId, username, guestId, isGuest, amount
            case splitStatus
            case paidDate, incomeTransactionId, requestId
            // Legacy keys for decoding old documents
            case isPaid, isAccepted, status
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
            friendId = try container.decodeIfPresent(String.self, forKey: .friendId)
            username = try container.decodeIfPresent(String.self, forKey: .username)
            guestId = try container.decodeIfPresent(String.self, forKey: .guestId)
            isGuest = try container.decodeIfPresent(Bool.self, forKey: .isGuest) ?? false
            amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0.0
            paidDate = try container.decodeIfPresent(Date.self, forKey: .paidDate)
            incomeTransactionId = try container.decodeIfPresent(String.self, forKey: .incomeTransactionId)
            requestId = try container.decodeIfPresent(String.self, forKey: .requestId)

            // Derive splitStatus: prefer new field, fall back to legacy fields
            if let decoded = try container.decodeIfPresent(SplitStatus.self, forKey: .splitStatus) {
                splitStatus = decoded
            } else if let legacyStatus = try container.decodeIfPresent(String.self, forKey: .status),
                      let parsed = SplitStatus(rawValue: legacyStatus) {
                splitStatus = parsed
            } else {
                let legacyPaid = try container.decodeIfPresent(Bool.self, forKey: .isPaid) ?? false
                let legacyAccepted = try container.decodeIfPresent(Bool.self, forKey: .isAccepted) ?? false
                if legacyPaid {
                    splitStatus = .paid
                } else if legacyAccepted {
                    splitStatus = .accepted
                } else {
                    splitStatus = .pending
                }
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(friendId, forKey: .friendId)
            try container.encodeIfPresent(username, forKey: .username)
            try container.encodeIfPresent(guestId, forKey: .guestId)
            try container.encode(isGuest, forKey: .isGuest)
            try container.encode(amount, forKey: .amount)
            try container.encode(splitStatus, forKey: .splitStatus)
            try container.encodeIfPresent(paidDate, forKey: .paidDate)
            try container.encodeIfPresent(incomeTransactionId, forKey: .incomeTransactionId)
            try container.encodeIfPresent(requestId, forKey: .requestId)
            // Write legacy fields for backward compatibility with cloud functions / older clients
            try container.encode(isPaid, forKey: .isPaid)
            try container.encode(isAccepted, forKey: .isAccepted)
            try container.encodeIfPresent(status, forKey: .status)
        }

        // Memberwise init for code that constructs splits directly
        init(
            id: String = UUID().uuidString,
            name: String,
            friendId: String? = nil,
            username: String? = nil,
            guestId: String? = nil,
            isGuest: Bool = false,
            amount: Double,
            splitStatus: SplitStatus = .pending,
            paidDate: Date? = nil,
            incomeTransactionId: String? = nil,
            requestId: String? = nil
        ) {
            self.id = id
            self.name = name
            self.friendId = friendId
            self.username = username
            self.guestId = guestId
            self.isGuest = isGuest
            self.amount = amount
            self.splitStatus = splitStatus
            self.paidDate = paidDate
            self.incomeTransactionId = incomeTransactionId
            self.requestId = requestId
        }
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
        var type: String? // Removed inline default to allow synthesize `decodeIfPresent`
        var userId: String
        var monthStartDate: Date
        var createdAt: Date
        
        // Backend Aggregation Fields (Must exist to satisfy CodingKeys if present in DB)
        var currentPeriodSpent: Double?
        var lastAggregatedAt: Date?
        
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
            case currentPeriodSpent
            case lastAggregatedAt
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
        /// Shows users their real spending when reimbursements are involved.
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
        var categoryId: String? // Backfilled by migration from name → budget lookup
        var icon: String? // Made optional: migration deletes this field
        var colorHex: String? // Made optional: migration deletes this field
        var note: String?
        var type: String? // Removed inline default to allow synthesize `decodeIfPresent`
        var userId: String
        var createdAt: Date
        var lastProcessedDate: Date? // For tracking auto-execution
        var source: String? // Identifies auto-created entries (e.g. "subscription")

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case amount
            case frequency
            case startDate
            case categoryId
            case icon
            case colorHex
            case note
            case type
            case userId
            case createdAt
            case lastProcessedDate
            case source
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
        
        enum CodingKeys: String, CodingKey {
            case id, date, editorId, editorName, field, oldValue, newValue
        }
        
        init(id: String = UUID().uuidString, date: Date, editorId: String, editorName: String, field: String, oldValue: String, newValue: String) {
            self.id = id
            self.date = date
            self.editorId = editorId
            self.editorName = editorName
            self.field = field
            self.oldValue = oldValue
            self.newValue = newValue
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
            editorId = try container.decodeIfPresent(String.self, forKey: .editorId) ?? ""
            editorName = try container.decodeIfPresent(String.self, forKey: .editorName) ?? "Unknown"
            field = try container.decodeIfPresent(String.self, forKey: .field) ?? ""
            oldValue = try container.decodeIfPresent(String.self, forKey: .oldValue) ?? ""
            newValue = try container.decodeIfPresent(String.self, forKey: .newValue) ?? ""
        }
    }

    struct TransactionModel: Codable, Identifiable, Equatable {
        static func == (lhs: TransactionModel, rhs: TransactionModel) -> Bool {
            lhs.id == rhs.id
        }

        @DocumentID var id: String?
        var userId: String
        var title: String
        var subtitle: String? // Category (Legacy)
        var categoryId: String? // Reference to CategoryBudget
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
            categoryId: String? = nil,
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
            self.categoryId = categoryId
            // FIX #11: Enforce sign convention — expenses are always negative, income always positive
            self.amount = TransactionModel.normalizeAmount(amount, type: type)
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



        /// FIX #11: Ensures expenses are negative and income is positive.
        static func normalizeAmount(_ amount: Double, type: String) -> Double {
            switch type.lowercased() {
            case "expense": return amount > 0 ? -amount : amount
            case "income": return amount < 0 ? -amount : amount
            default: return amount
            }
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
        var categoryId: String? // Reference to CategoryBudget
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
            case categoryId
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
        var currency: String? // ✅ NEW: Multi-currency support (FIX #9: defaults to mainCurrency on read)
        
        /// FIX #9: Resolved currency — never nil. Falls back to user's main currency for legacy splits.
        var resolvedCurrency: String {
            currency ?? CurrencyManager.shared.mainCurrency
        }
        var note: String?
        var category: String? // ✅ NEW: For UI display
        var icon: String? // ✅ NEW: For UI display
        var colorHex: String? // ✅ NEW: For UI display
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
        var isPremium: Bool? = false
        var avatarColor: String? // ✅ NEW: User's profile color (hex string)
        var badgeType: String? // Premium badge style (king/pro/saver)
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
            case isPremium
            case avatarColor
            case badgeType
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
