import Foundation
import FirebaseFirestore

extension FirestoreModels {

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
            case id, name, normalizedName, members
            // Legacy key for memberIds, which was renamed to members in schema v2
            case memberIds
            case memberNames, createdBy, icon, color
            // Legacy key for colorHex, which was renamed to color in schema v2
            case colorHex
            case createdAt, updatedAt, defaultCurrency, deletionStatus, memberActions, schemaVersion
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
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
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
        var receiverId: String?
        var receiverName: String?
        var date: Date
        var type: String // "expense" or "income" (reimbursement)
        var currencyCode: String?
        var note: String?
        var categoryId: String? // Reference to CategoryBudget
        var category: String?
        var icon: String?
        var colorHex: String?
        var originalTransactionId: String? // Linked to the user's private transaction
        var originalAmount: Double?
        var exchangeRate: Double?
        var latitude: Double?
        var longitude: Double?
        var involvedUserStatuses: [String: String]? // Maps userId to RequestStatus string
        var editHistory: [EditRecord]?

        enum CodingKeys: String, CodingKey {
            case id, title, amount, payerId, payerName, receiverId, receiverName
            case date, type, currencyCode, note, categoryId, category, icon, colorHex
            case originalTransactionId, originalAmount, exchangeRate
            case latitude, longitude, involvedUserStatuses, editHistory
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
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
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
            case id, groupId, groupName, fromUid, toUid, status, dependencyId, createdAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
            groupId = try container.decodeIfPresent(String.self, forKey: .groupId) ?? ""
            groupName = try container.decodeIfPresent(String.self, forKey: .groupName) ?? "Unknown Group"
            fromUid = try container.decodeIfPresent(String.self, forKey: .fromUid) ?? ""
            toUid = try container.decodeIfPresent(String.self, forKey: .toUid) ?? ""
            status = try container.decodeIfPresent(String.self, forKey: .status) ?? "pending"
            dependencyId = try container.decodeIfPresent(String.self, forKey: .dependencyId)
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        }
    }
}
