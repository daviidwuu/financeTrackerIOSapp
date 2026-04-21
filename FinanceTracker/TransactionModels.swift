import Foundation
import FirebaseFirestore

extension FirestoreModels {

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
            if let decoded = try container.decodeIfPresent(SplitStatus.self, forKey: .splitStatus) {
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

    // MARK: - Edit Record
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
            case id, name, amount, frequency, startDate, categoryId, icon, colorHex
            case note, type, userId, createdAt, lastProcessedDate, source
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
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
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

    // MARK: - TransactionModel
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
            case id, userId, title, subtitle, categoryId, amount, date, type, createdAt
            case icon, colorHex, note, source
            case latitude, longitude, locationName
            case splits, originalAmount, currencyCode, exchangeRate
            case editHistory, schemaVersion
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
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
}
