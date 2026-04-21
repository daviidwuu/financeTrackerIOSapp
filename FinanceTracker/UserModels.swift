import Foundation
import FirebaseFirestore

extension FirestoreModels {

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
            case id, name, email, username, isPremium, avatarColor, badgeType, createdAt
            case points, completedMissionIds, streakCount, lastVisitDate, schemaVersion
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            _id = try container.decode(DocumentID<String>.self, forKey: .id)
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
            case id, title, cost, icon, partnerName, description, colorHex
            case region, category, expiryDays, isActive, partnerLogo, rewardType
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
            case id, rewardId, rewardTitle, rewardIcon, cost, date, code, expiresAt, status, partnerName
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
