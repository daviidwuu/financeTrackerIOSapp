import Foundation
import FirebaseFirestore

enum FirestoreModels {



    
    // MARK: - Split Status Enum
    enum SplitStatus: String, Codable {
        case pending
        case accepted
        case declined
        case paid
        /// Fallback for any server value not yet known to this client version.
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = SplitStatus(rawValue: rawValue) ?? .unknown
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

            // Derive splitStatus: prefer new field, fall back to legacy fields.
            // Note: SplitStatus.init(from:) handles unknown raw values via .unknown fallback,
            // so decoding here will never throw on an unrecognized server value.
            if let decoded = try container.decodeIfPresent(SplitStatus.self, forKey: .splitStatus) {
                // Treat an unknown server value as pending (safe display default).
                splitStatus = decoded == .unknown ? .pending : decoded
            } else if let legacyStatus = try container.decodeIfPresent(String.self, forKey: .status),
                      let parsed = SplitStatus(rawValue: legacyStatus) {
                splitStatus = parsed == .unknown ? .pending : parsed
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

        init(
            id: String? = nil,
            name: String,
            avatarColor: String,
            totalOwed: Double = 0,
            createdAt: Date = Date(),
            userId: String
        ) {
            self.id = id
            self.name = name
            self.avatarColor = avatarColor
            self.totalOwed = totalOwed
            self.createdAt = createdAt
            self.userId = userId
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
            avatarColor = try container.decodeIfPresent(String.self, forKey: .avatarColor) ?? "#FF9500"
            totalOwed = try container.decodeIfPresent(Double.self, forKey: .totalOwed) ?? 0.0
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
            userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        }
    }

    // MARK: - FriendRequest Model
    struct FriendRequest: Identifiable, Codable {
        @DocumentID var id: String?
        var fromUid: String
        var toUid: String
        var status: String // "pending", "accepted", "declined"
        var fromName: String? // For UI display
        var fromUsername: String? // For UI display
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

        init(
            id: String? = nil,
            fromUid: String,
            toUid: String,
            status: String = "pending",
            fromName: String? = nil,
            fromUsername: String? = nil,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.fromUid = fromUid
            self.toUid = toUid
            self.status = status
            self.fromName = fromName
            self.fromUsername = fromUsername
            self.createdAt = createdAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            fromUid = try container.decodeIfPresent(String.self, forKey: .fromUid) ?? ""
            toUid = try container.decodeIfPresent(String.self, forKey: .toUid) ?? ""
            status = try container.decodeIfPresent(String.self, forKey: .status) ?? "pending"
            fromName = try container.decodeIfPresent(String.self, forKey: .fromName)
            fromUsername = try container.decodeIfPresent(String.self, forKey: .fromUsername)
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            groupId = try container.decodeIfPresent(String.self, forKey: .groupId) ?? ""
            groupName = try container.decodeIfPresent(String.self, forKey: .groupName) ?? "Unknown Group"
            fromUid = try container.decodeIfPresent(String.self, forKey: .fromUid) ?? ""
            toUid = try container.decodeIfPresent(String.self, forKey: .toUid) ?? ""
            status = try container.decodeIfPresent(String.self, forKey: .status) ?? "pending"
            dependencyId = try container.decodeIfPresent(String.self, forKey: .dependencyId)
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
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
            id = try container.decodeIfPresent(String.self, forKey: .id)
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
            id = try container.decodeIfPresent(String.self, forKey: .id)
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

        init(
            id: String? = nil,
            name: String,
            amount: Double,
            frequency: String,
            startDate: Date = Date(),
            categoryId: String? = nil,
            icon: String? = nil,
            colorHex: String? = nil,
            note: String? = nil,
            type: String? = nil,
            userId: String,
            createdAt: Date = Date(),
            lastProcessedDate: Date? = nil,
            source: String? = nil
        ) {
            self.id = id
            self.name = name
            self.amount = amount
            self.frequency = frequency
            self.startDate = startDate
            self.categoryId = categoryId
            self.icon = icon
            self.colorHex = colorHex
            self.note = note
            self.type = type
            self.userId = userId
            self.createdAt = createdAt
            self.lastProcessedDate = lastProcessedDate
            self.source = source
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
            amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0.0
            frequency = try container.decodeIfPresent(String.self, forKey: .frequency) ?? "Monthly"
            startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
            categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
            icon = try container.decodeIfPresent(String.self, forKey: .icon)
            colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
            note = try container.decodeIfPresent(String.self, forKey: .note)
            type = try container.decodeIfPresent(String.self, forKey: .type)
            userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
            lastProcessedDate = try container.decodeIfPresent(Date.self, forKey: .lastProcessedDate)
            source = try container.decodeIfPresent(String.self, forKey: .source)
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
        // MARK: - Schema version
        // v1: original schema
        // v2: added splits, originalAmount, currencyCode, exchangeRate
        // v3: added editHistory, source, location fields
        static let currentSchemaVersion = 3

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
        var source: String?

        // Location
        var latitude: Double?
        var longitude: Double?
        var locationName: String?

        // Splits
        var splits: [Split]?
        var originalAmount: Double? // Before split
        var currencyCode: String?
        var exchangeRate: Double?

        var editHistory: [EditRecord]?

        // Schema version stored in Firestore; optional so old documents without it still decode.
        var schemaVersion: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case userId
            case title
            case subtitle
            case categoryId
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
            case schemaVersion
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
            subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
            amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0.0
            date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
            type = try container.decodeIfPresent(String.self, forKey: .type) ?? "expense"
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
            icon = try container.decodeIfPresent(String.self, forKey: .icon)
            colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
            note = try container.decodeIfPresent(String.self, forKey: .note)
            source = try container.decodeIfPresent(String.self, forKey: .source)
            latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
            longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
            locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
            splits = try container.decodeIfPresent([Split].self, forKey: .splits)
            originalAmount = try container.decodeIfPresent(Double.self, forKey: .originalAmount)
            currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
            exchangeRate = try container.decodeIfPresent(Double.self, forKey: .exchangeRate)
            editHistory = try container.decodeIfPresent([EditRecord].self, forKey: .editHistory)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
        }

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
            editHistory: [EditRecord]? = nil,
            schemaVersion: Int? = nil
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
            self.schemaVersion = schemaVersion
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
        // MARK: - Schema version
        // v1: original schema (memberIds, colorHex field names)
        // v2: renamed memberIds → members, colorHex → color; added createdBy, normalizedName,
        //     memberNames, updatedAt, defaultCurrency, deletionStatus, memberActions
        static let currentSchemaVersion = 2

        @DocumentID var id: String?
        var name: String
        var normalizedName: String? // For duplicate detection
        var members: [String] // RENAMED from memberIds (legacy fallback in init(from:))
        var memberNames: [String: String]? // Denormalized map [UID: Name]
        var createdBy: String // Track creator
        var icon: String
        var color: String // RENAMED from colorHex (legacy fallback in init(from:))
        var createdAt: Date
        var updatedAt: Date? // Track modifications
        var defaultCurrency: String? // Master currency for the group
        var deletionStatus: String? // "requested" or nil
        var memberActions: [String: String]? // Map [UID: "keep" | "delete"]

        // Schema version stored in Firestore; optional so old documents without it still decode.
        var schemaVersion: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case normalizedName
            case members
            // Legacy key for memberIds, which was renamed to members in schema v2
            case memberIds
            case memberNames
            case createdBy
            case icon
            case color
            // Legacy key for colorHex, which was renamed to color in schema v2
            case colorHex
            case createdAt
            case updatedAt
            case defaultCurrency
            case deletionStatus
            case memberActions
            case schemaVersion
        }

        init(
            id: String? = nil,
            name: String,
            normalizedName: String? = nil,
            members: [String],
            memberNames: [String: String]? = nil,
            createdBy: String,
            icon: String,
            color: String,
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            defaultCurrency: String? = nil,
            deletionStatus: String? = nil,
            memberActions: [String: String]? = nil,
            schemaVersion: Int? = nil
        ) {
            self.id = id
            self.name = name
            self.normalizedName = normalizedName
            self.members = members
            self.memberNames = memberNames
            self.createdBy = createdBy
            self.icon = icon
            self.color = color
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.defaultCurrency = defaultCurrency
            self.deletionStatus = deletionStatus
            self.memberActions = memberActions
            self.schemaVersion = schemaVersion
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unnamed Group"
            normalizedName = try container.decodeIfPresent(String.self, forKey: .normalizedName)
            // Prefer new field name `members`; fall back to legacy `memberIds`
            if let newMembers = try container.decodeIfPresent([String].self, forKey: .members) {
                members = newMembers
            } else {
                members = try container.decodeIfPresent([String].self, forKey: .memberIds) ?? []
            }
            memberNames = try container.decodeIfPresent([String: String].self, forKey: .memberNames)
            createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy) ?? ""
            icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "person.3"
            // Prefer new field name `color`; fall back to legacy `colorHex`
            if let newColor = try container.decodeIfPresent(String.self, forKey: .color) {
                color = newColor
            } else {
                color = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#888888"
            }
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
            updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
            defaultCurrency = try container.decodeIfPresent(String.self, forKey: .defaultCurrency)
            deletionStatus = try container.decodeIfPresent(String.self, forKey: .deletionStatus)
            memberActions = try container.decodeIfPresent([String: String].self, forKey: .memberActions)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(normalizedName, forKey: .normalizedName)
            try container.encode(members, forKey: .members)
            try container.encodeIfPresent(memberNames, forKey: .memberNames)
            try container.encode(createdBy, forKey: .createdBy)
            try container.encode(icon, forKey: .icon)
            try container.encode(color, forKey: .color)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
            try container.encodeIfPresent(defaultCurrency, forKey: .defaultCurrency)
            try container.encodeIfPresent(deletionStatus, forKey: .deletionStatus)
            try container.encodeIfPresent(memberActions, forKey: .memberActions)
            try container.encodeIfPresent(schemaVersion, forKey: .schemaVersion)
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

        init(
            id: String? = nil,
            title: String,
            amount: Double,
            payerId: String,
            payerName: String,
            receiverId: String? = nil,
            receiverName: String? = nil,
            date: Date = Date(),
            type: String,
            currencyCode: String? = nil,
            note: String? = nil,
            categoryId: String? = nil,
            category: String? = nil,
            icon: String? = nil,
            colorHex: String? = nil,
            originalTransactionId: String? = nil,
            originalAmount: Double? = nil,
            exchangeRate: Double? = nil,
            latitude: Double? = nil,
            longitude: Double? = nil,
            involvedUserStatuses: [String: String]? = nil,
            editHistory: [EditRecord]? = nil
        ) {
            self.id = id
            self.title = title
            self.amount = amount
            self.payerId = payerId
            self.payerName = payerName
            self.receiverId = receiverId
            self.receiverName = receiverName
            self.date = date
            self.type = type
            self.currencyCode = currencyCode
            self.note = note
            self.categoryId = categoryId
            self.category = category
            self.icon = icon
            self.colorHex = colorHex
            self.originalTransactionId = originalTransactionId
            self.originalAmount = originalAmount
            self.exchangeRate = exchangeRate
            self.latitude = latitude
            self.longitude = longitude
            self.involvedUserStatuses = involvedUserStatuses
            self.editHistory = editHistory
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
            amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0.0
            payerId = try container.decodeIfPresent(String.self, forKey: .payerId) ?? ""
            payerName = try container.decodeIfPresent(String.self, forKey: .payerName) ?? "Unknown"
            receiverId = try container.decodeIfPresent(String.self, forKey: .receiverId)
            receiverName = try container.decodeIfPresent(String.self, forKey: .receiverName)
            date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
            type = try container.decodeIfPresent(String.self, forKey: .type) ?? "expense"
            currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
            note = try container.decodeIfPresent(String.self, forKey: .note)
            categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
            category = try container.decodeIfPresent(String.self, forKey: .category)
            icon = try container.decodeIfPresent(String.self, forKey: .icon)
            colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
            originalTransactionId = try container.decodeIfPresent(String.self, forKey: .originalTransactionId)
            originalAmount = try container.decodeIfPresent(Double.self, forKey: .originalAmount)
            exchangeRate = try container.decodeIfPresent(Double.self, forKey: .exchangeRate)
            latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
            longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
            involvedUserStatuses = try container.decodeIfPresent([String: String].self, forKey: .involvedUserStatuses)
            editHistory = try container.decodeIfPresent([EditRecord].self, forKey: .editHistory)
        }
    }

    // MARK: - SplitRequest Model
    struct SplitRequest: Identifiable, Codable {
        // MARK: - Schema version
        // v1: original schema (requesterId field name)
        // v2: renamed requesterId → fromUid; added toUid, toName, currency, groupId,
        //     dependencyId, lastNudgedAt, hiddenFor, originalTotalAmount, isGuest,
        //     isSettlement, latitude, longitude, category, icon, colorHex
        // v3: added settledByRequestId (P0-1: tracks which settlement request closed this split)
        static let currentSchemaVersion = 3

        @DocumentID var id: String?
        var transactionId: String
        var groupId: String? // Link to group
        var fromUid: String // RENAMED from requesterId (legacy fallback in init(from:))
        var toUid: String // Explicit receiver
        var fromName: String? // Denormalized sender name
        var toName: String? // Denormalized receiver name (Friend or Guest)
        var amount: Double
        var currency: String? // Multi-currency support (FIX #9: defaults to mainCurrency on read)

        /// FIX #9: Resolved currency — never nil. Falls back to user's main currency for legacy splits.
        var resolvedCurrency: String {
            currency ?? CurrencyManager.shared.mainCurrency
        }
        var note: String?
        var category: String? // For UI display
        var icon: String? // For UI display
        var colorHex: String? // For UI display
        var status: RequestStatus // CHANGED to enum
        var dependencyId: String? // Links to blocking document
        var lastNudgedAt: Date? // For nudge feature
        var hiddenFor: [String]? // User IDs who have hidden this split from their view
        var originalTotalAmount: Double? // Full pre-split expense total
        var isGuest: Bool? // Flag to distinguish guest split requests
        var isSettlement: Bool? // Flag to distinguish settlement requests from regular splits
        var latitude: Double? // Maps location support
        var longitude: Double? // Maps location support
        var createdAt: Date

        /// The ID of the SplitRequest that settled/closed this split (added in P0-1).
        /// Optional so documents written before this field was added still decode correctly.
        var settledByRequestId: String?

        // Schema version stored in Firestore; optional so old documents without it still decode.
        var schemaVersion: Int?

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
            // Legacy key for requesterId, which was renamed to fromUid in schema v2
            case requesterId
            case toUid
            case fromName
            case toName
            case amount
            case currency
            case note
            case category
            case icon
            case colorHex
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
            case settledByRequestId
            case schemaVersion
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            transactionId = try container.decodeIfPresent(String.self, forKey: .transactionId) ?? ""
            groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
            // Prefer new field name `fromUid`; fall back to legacy `requesterId`
            if let newFromUid = try container.decodeIfPresent(String.self, forKey: .fromUid) {
                fromUid = newFromUid
            } else {
                fromUid = try container.decodeIfPresent(String.self, forKey: .requesterId) ?? ""
            }
            toUid = try container.decodeIfPresent(String.self, forKey: .toUid) ?? ""
            fromName = try container.decodeIfPresent(String.self, forKey: .fromName)
            toName = try container.decodeIfPresent(String.self, forKey: .toName)
            amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0.0
            currency = try container.decodeIfPresent(String.self, forKey: .currency)
            note = try container.decodeIfPresent(String.self, forKey: .note)
            category = try container.decodeIfPresent(String.self, forKey: .category)
            icon = try container.decodeIfPresent(String.self, forKey: .icon)
            colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
            status = try container.decodeIfPresent(RequestStatus.self, forKey: .status) ?? .pending
            dependencyId = try container.decodeIfPresent(String.self, forKey: .dependencyId)
            lastNudgedAt = try container.decodeIfPresent(Date.self, forKey: .lastNudgedAt)
            hiddenFor = try container.decodeIfPresent([String].self, forKey: .hiddenFor)
            originalTotalAmount = try container.decodeIfPresent(Double.self, forKey: .originalTotalAmount)
            isGuest = try container.decodeIfPresent(Bool.self, forKey: .isGuest)
            isSettlement = try container.decodeIfPresent(Bool.self, forKey: .isSettlement)
            latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
            longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
            settledByRequestId = try container.decodeIfPresent(String.self, forKey: .settledByRequestId)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
        }

        init(
            id: String? = nil,
            transactionId: String,
            groupId: String? = nil,
            fromUid: String,
            toUid: String,
            fromName: String? = nil,
            toName: String? = nil,
            amount: Double,
            currency: String? = nil,
            note: String? = nil,
            category: String? = nil,
            icon: String? = nil,
            colorHex: String? = nil,
            status: RequestStatus,
            dependencyId: String? = nil,
            lastNudgedAt: Date? = nil,
            hiddenFor: [String]? = nil,
            originalTotalAmount: Double? = nil,
            isGuest: Bool? = nil,
            isSettlement: Bool? = nil,
            latitude: Double? = nil,
            longitude: Double? = nil,
            createdAt: Date = Date(),
            settledByRequestId: String? = nil,
            schemaVersion: Int? = nil
        ) {
            self.id = id
            self.transactionId = transactionId
            self.groupId = groupId
            self.fromUid = fromUid
            self.toUid = toUid
            self.fromName = fromName
            self.toName = toName
            self.amount = amount
            self.currency = currency
            self.note = note
            self.category = category
            self.icon = icon
            self.colorHex = colorHex
            self.status = status
            self.dependencyId = dependencyId
            self.lastNudgedAt = lastNudgedAt
            self.hiddenFor = hiddenFor
            self.originalTotalAmount = originalTotalAmount
            self.isGuest = isGuest
            self.isSettlement = isSettlement
            self.latitude = latitude
            self.longitude = longitude
            self.createdAt = createdAt
            self.settledByRequestId = settledByRequestId
            self.schemaVersion = schemaVersion
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(transactionId, forKey: .transactionId)
            try container.encodeIfPresent(groupId, forKey: .groupId)
            try container.encode(fromUid, forKey: .fromUid)
            try container.encode(toUid, forKey: .toUid)
            try container.encodeIfPresent(fromName, forKey: .fromName)
            try container.encodeIfPresent(toName, forKey: .toName)
            try container.encode(amount, forKey: .amount)
            try container.encodeIfPresent(currency, forKey: .currency)
            try container.encodeIfPresent(note, forKey: .note)
            try container.encodeIfPresent(category, forKey: .category)
            try container.encodeIfPresent(icon, forKey: .icon)
            try container.encodeIfPresent(colorHex, forKey: .colorHex)
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(dependencyId, forKey: .dependencyId)
            try container.encodeIfPresent(lastNudgedAt, forKey: .lastNudgedAt)
            try container.encodeIfPresent(hiddenFor, forKey: .hiddenFor)
            try container.encodeIfPresent(originalTotalAmount, forKey: .originalTotalAmount)
            try container.encodeIfPresent(isGuest, forKey: .isGuest)
            try container.encodeIfPresent(isSettlement, forKey: .isSettlement)
            try container.encodeIfPresent(latitude, forKey: .latitude)
            try container.encodeIfPresent(longitude, forKey: .longitude)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(settledByRequestId, forKey: .settledByRequestId)
            try container.encodeIfPresent(schemaVersion, forKey: .schemaVersion)
        }
    }

    // MARK: - Friend Model
    struct Friend: Identifiable, Codable, Hashable {
        @DocumentID var id: String? // The Friend's User ID
        var username: String? // Optional to handle decoding failures on old documents
        var name: String // Display Name
        var email: String? // Optional
        var avatarColor: String? // For consistent UI color
        var addedAt: Date? // Made optional

        enum CodingKeys: String, CodingKey {
            case id
            case username
            case name
            case email
            case avatarColor
            case addedAt
        }

        init(
            id: String? = nil,
            username: String? = nil,
            name: String,
            email: String? = nil,
            avatarColor: String? = nil,
            addedAt: Date? = nil
        ) {
            self.id = id
            self.username = username
            self.name = name
            self.email = email
            self.avatarColor = avatarColor
            self.addedAt = addedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            username = try container.decodeIfPresent(String.self, forKey: .username)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
            email = try container.decodeIfPresent(String.self, forKey: .email)
            avatarColor = try container.decodeIfPresent(String.self, forKey: .avatarColor)
            addedAt = try container.decodeIfPresent(Date.self, forKey: .addedAt)
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
        // MARK: - Schema version
        // v1: original schema
        // v2: added isPremium, avatarColor, badgeType, gamification fields (points,
        //     completedMissionIds, streakCount, lastVisitDate)
        static let currentSchemaVersion = 2

        @DocumentID var id: String?
        var name: String
        var email: String
        var username: String
        var isPremium: Bool? // defaults to false when absent
        var avatarColor: String? // User's profile color (hex string); default #FF9500
        var badgeType: String? // Premium badge style (king/pro/saver)
        var createdAt: Date

        // Gamification
        var points: Int? // defaults to 0 when absent
        var completedMissionIds: [String]? // defaults to [] when absent
        var streakCount: Int? // defaults to 1 when absent
        var lastVisitDate: Date?

        // Schema version stored in Firestore; optional so old documents without it still decode.
        var schemaVersion: Int?

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
            case schemaVersion
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
            email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
            username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
            isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
            avatarColor = try container.decodeIfPresent(String.self, forKey: .avatarColor)
            badgeType = try container.decodeIfPresent(String.self, forKey: .badgeType)
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
            points = try container.decodeIfPresent(Int.self, forKey: .points) ?? 0
            completedMissionIds = try container.decodeIfPresent([String].self, forKey: .completedMissionIds) ?? []
            streakCount = try container.decodeIfPresent(Int.self, forKey: .streakCount) ?? 1
            lastVisitDate = try container.decodeIfPresent(Date.self, forKey: .lastVisitDate)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
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
        var region: String?      // "SG", "US", "GLOBAL"
        var category: String?    // "food", "shopping", "cash", "transport"
        var expiryDays: Int?     // Days until code expires after redemption
        var isActive: Bool?      // Admin can enable/disable
        var partnerLogo: String? // URL to partner logo image
        var rewardType: String?  // "voucher", "paypal", "giftcard"

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case cost
            case icon
            case partnerName
            case description
            case colorHex
            case region
            case category
            case expiryDays
            case isActive
            case partnerLogo
            case rewardType
        }

        init(
            id: String,
            title: String,
            cost: Int,
            icon: String,
            partnerName: String,
            description: String,
            colorHex: String,
            region: String? = nil,
            category: String? = nil,
            expiryDays: Int? = nil,
            isActive: Bool? = nil,
            partnerLogo: String? = nil,
            rewardType: String? = nil
        ) {
            self.id = id
            self.title = title
            self.cost = cost
            self.icon = icon
            self.partnerName = partnerName
            self.description = description
            self.colorHex = colorHex
            self.region = region
            self.category = category
            self.expiryDays = expiryDays
            self.isActive = isActive
            self.partnerLogo = partnerLogo
            self.rewardType = rewardType
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Unknown Reward"
            cost = try container.decodeIfPresent(Int.self, forKey: .cost) ?? 0
            icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "gift"
            partnerName = try container.decodeIfPresent(String.self, forKey: .partnerName) ?? ""
            description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
            colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#888888"
            region = try container.decodeIfPresent(String.self, forKey: .region)
            category = try container.decodeIfPresent(String.self, forKey: .category)
            expiryDays = try container.decodeIfPresent(Int.self, forKey: .expiryDays)
            isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
            partnerLogo = try container.decodeIfPresent(String.self, forKey: .partnerLogo)
            rewardType = try container.decodeIfPresent(String.self, forKey: .rewardType)
        }
    }

    struct Redemption: Identifiable, Codable {
        var id: String
        var rewardId: String
        var rewardTitle: String
        var rewardIcon: String
        var cost: Int
        var date: Date
        var code: String         // Unique redemption code
        var expiresAt: Date?     // When the code expires
        var status: String?      // "active", "used", "expired"
        var partnerName: String? // For display

        enum CodingKeys: String, CodingKey {
            case id
            case rewardId
            case rewardTitle
            case rewardIcon
            case cost
            case date
            case code
            case expiresAt
            case status
            case partnerName
        }

        init(
            id: String = UUID().uuidString,
            rewardId: String,
            rewardTitle: String,
            rewardIcon: String,
            cost: Int,
            date: Date = Date(),
            code: String,
            expiresAt: Date? = nil,
            status: String? = nil,
            partnerName: String? = nil
        ) {
            self.id = id
            self.rewardId = rewardId
            self.rewardTitle = rewardTitle
            self.rewardIcon = rewardIcon
            self.cost = cost
            self.date = date
            self.code = code
            self.expiresAt = expiresAt
            self.status = status
            self.partnerName = partnerName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            rewardId = try container.decodeIfPresent(String.self, forKey: .rewardId) ?? ""
            rewardTitle = try container.decodeIfPresent(String.self, forKey: .rewardTitle) ?? "Unknown"
            rewardIcon = try container.decodeIfPresent(String.self, forKey: .rewardIcon) ?? "gift"
            cost = try container.decodeIfPresent(Int.self, forKey: .cost) ?? 0
            date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
            code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
            expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
            status = try container.decodeIfPresent(String.self, forKey: .status)
            partnerName = try container.decodeIfPresent(String.self, forKey: .partnerName)
        }
    }
}
