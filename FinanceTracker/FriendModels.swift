import Foundation
import FirebaseFirestore

extension FirestoreModels {

    // MARK: - Guest Model
    struct Guest: Identifiable, Codable {
        @DocumentID var id: String?
        var name: String
        var avatarColor: String // For consistent UI color (random hex)
        var totalOwed: Double // Aggregate debt across all transactions
        var createdAt: Date
        var userId: String // Owner of this guest record

        enum CodingKeys: String, CodingKey {
            case id, name, avatarColor, totalOwed, createdAt, userId
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
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
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
            case id, fromUid, toUid, status, fromName, fromUsername, createdAt
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
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
            fromUid = try container.decodeIfPresent(String.self, forKey: .fromUid) ?? ""
            toUid = try container.decodeIfPresent(String.self, forKey: .toUid) ?? ""
            status = try container.decodeIfPresent(String.self, forKey: .status) ?? "pending"
            fromName = try container.decodeIfPresent(String.self, forKey: .fromName)
            fromUsername = try container.decodeIfPresent(String.self, forKey: .fromUsername)
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
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
            case id, username, name, email, avatarColor, addedAt
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
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
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
        var currency: String? // Multi-currency support

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
            case id, transactionId, groupId, fromUid
            // Legacy key for requesterId, which was renamed to fromUid in schema v2
            case requesterId
            case toUid, fromName, toName, amount, currency, note, category, icon, colorHex
            case status, dependencyId, lastNudgedAt, hiddenFor, originalTotalAmount
            case isGuest, isSettlement, latitude, longitude, createdAt, settledByRequestId, schemaVersion
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
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
}
