import SwiftUI

struct Bucket: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var colorHex: String
    var isActive: Bool
    var archived: Bool
    var goal: Double?
    var goalDate: String?
    var isSpending: Bool
    var order: Int
    // The catch-all for savings that aren't explicitly assigned to a bucket.
    // Exactly one bucket should carry this flag; it can't be deleted or
    // switched to a spending bucket, since bucket balances + this one must
    // always sum to total savings.
    var isGeneral: Bool
    // Intended per-check allocation, shown as a quick-fill suggestion when
    // adding income. At most one of these should be set — percent (0-100)
    // or a fixed dollar amount.
    var allocationPercent: Double?
    var allocationAmount: Double?
    // SF Symbol name shown next to the bucket's color, e.g. in a Reminders-
    // list-style badge. Nil means "just the color" — buckets whose name
    // already carries an emoji don't need a redundant icon forced on them.
    var iconName: String?

    var color: Color { Color(hex: colorHex) }

    init(id: String, name: String, colorHex: String, isActive: Bool, archived: Bool, goal: Double?, goalDate: String? = nil, isSpending: Bool, order: Int, isGeneral: Bool = false, allocationPercent: Double? = nil, allocationAmount: Double? = nil, iconName: String? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isActive = isActive
        self.archived = archived
        self.goal = goal
        self.goalDate = goalDate
        self.isSpending = isSpending
        self.order = order
        self.isGeneral = isGeneral
        self.allocationPercent = allocationPercent
        self.allocationAmount = allocationAmount
        self.iconName = iconName
    }

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, isActive, archived, goal, goalDate, isSpending, order, isGeneral, allocationPercent, allocationAmount, iconName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        archived = try container.decode(Bool.self, forKey: .archived)
        goal = try container.decodeIfPresent(Double.self, forKey: .goal)
        goalDate = try container.decodeIfPresent(String.self, forKey: .goalDate)
        isSpending = try container.decode(Bool.self, forKey: .isSpending)
        order = try container.decode(Int.self, forKey: .order)
        isGeneral = try container.decodeIfPresent(Bool.self, forKey: .isGeneral) ?? false
        allocationPercent = try container.decodeIfPresent(Double.self, forKey: .allocationPercent)
        allocationAmount = try container.decodeIfPresent(Double.self, forKey: .allocationAmount)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
    }
}
