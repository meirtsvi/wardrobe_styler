// Taxonomy enums (PLAN §5.3, §5.6). Literal cases are declared here; TaxonomyTests asserts they match shared/schemas/taxonomy.json.
import Foundation

public enum Category: String, Codable, CaseIterable, Sendable {
    case onePiece = "one_piece", top, midLayer = "mid_layer", outerwear, bottom, shoes, bag, jewelry, accessory, swim, underwear, other
}

public enum Slot: String, Codable, CaseIterable, Sendable {
    case onePiece = "one_piece", top, baseLayer = "base_layer", midLayer = "mid_layer", outerwear, bottom, shoes, bag, jewelry, accessory

    public static let clothing: [Slot] = [.onePiece, .top, .baseLayer, .midLayer, .outerwear, .bottom]
}

public enum LayerRole: String, Codable, CaseIterable, Sendable { case base, single, mid, outer }
public enum Warmth: String, Codable, CaseIterable, Sendable { case light, mid, warm, heavy }
public enum Formality: String, Codable, CaseIterable, Sendable { case casual, smartCasual = "smart_casual", business, formal, athletic }
public enum Season: String, Codable, CaseIterable, Sendable { case spring, summer, autumn, winter }
public enum Occasion: String, Codable, CaseIterable, Sendable { case work, casual, date, event, travel, sport, beach, gym, formal, evening }
public enum AccessoryCount: String, Codable, CaseIterable, Sendable { case none, some, many }
public enum ItemStatus: String, Codable, CaseIterable, Sendable { case new, auto, confirmed, archived }
public enum AvailabilityState: String, Codable, CaseIterable, Sendable { case available, laundry, repair, packed, lent }

/// The decoded shared/schemas/taxonomy.json.
public struct Taxonomy: Decodable, Sendable {
    public struct AccessoryLimits: Decodable, Sendable {
        public let jewelry: Int
        public let accessory: Int
    }
    public struct History: Decodable, Sendable {
        public let noRepeatDays: Int
        public let maxReusedFromYesterday: Int
        public let coverageFullDays: Int
        public let subcategoryPenaltyDays: Int
        enum CodingKeys: String, CodingKey {
            case noRepeatDays = "no_repeat_days", maxReusedFromYesterday = "max_reused_from_yesterday"
            case coverageFullDays = "coverage_full_days", subcategoryPenaltyDays = "subcategory_penalty_days"
        }
    }

    public let version: Int
    public let categories: [String]
    public let subcategories: [String: [String]]
    public let layerRoles: [String]
    public let topLayerRoleDefaults: [String: String]
    public let slots: [String]
    public let slotMaxItems: [String: Int]
    public let slotCategories: [String: [String]]
    public let warmth: [String]
    public let seasons: [String]
    public let formality: [String]
    public let formalityOrder: [String]
    public let occasions: [String]
    public let occasionFormality: [String: [String]]
    public let occasionAllowsSwimUnderwear: [String]
    public let accessoryCount: [String: AccessoryLimits]
    public let itemStatus: [String]
    public let availabilityState: [String]
    public let history: History

    enum CodingKeys: String, CodingKey {
        case version, categories, subcategories, slots, warmth, seasons, formality, occasions, history
        case layerRoles = "layer_roles", topLayerRoleDefaults = "top_layer_role_defaults"
        case slotMaxItems = "slot_max_items", slotCategories = "slot_categories"
        case formalityOrder = "formality_order", occasionFormality = "occasion_formality"
        case occasionAllowsSwimUnderwear = "occasion_allows_swim_underwear", accessoryCount = "accessory_count"
        case itemStatus = "item_status", availabilityState = "availability_state"
    }

    public static let shared: Taxonomy = SharedResources.decode("taxonomy")

    public func slotAccepts(_ slot: Slot, category: Category) -> Bool {
        slotCategories[slot.rawValue]?.contains(category.rawValue) ?? false
    }

    public func maxItems(in slot: Slot) -> Int { slotMaxItems[slot.rawValue] ?? 1 }

    /// In the occasion's set, or one step from its primary target (§5.6 "±1 step"). Athletic only where the set names it.
    public func formalityAllowed(_ formality: Formality, for occasion: Occasion) -> Bool {
        let set = occasionFormality[occasion.rawValue] ?? []
        if set.contains(formality.rawValue) { return true }
        if formality == .athletic { return false }
        guard let primary = set.first, primary != "athletic",
              let a = formalityOrder.firstIndex(of: primary), let b = formalityOrder.firstIndex(of: formality.rawValue) else { return false }
        return abs(a - b) <= 1
    }

    public func limits(for count: AccessoryCount) -> AccessoryLimits {
        accessoryCount[count.rawValue] ?? AccessoryLimits(jewelry: 0, accessory: 0)
    }

    public func defaultLayerRole(category: Category, subcategory: String) -> LayerRole? {
        guard category == .top || category == .midLayer else { return nil }
        if let raw = topLayerRoleDefaults[subcategory], let role = LayerRole(rawValue: raw) { return role }
        return category == .midLayer ? .mid : .single
    }

    public var allSubcategories: [String] { subcategories.values.flatMap { $0 } }
}

enum SharedResources {
    static func decode<T: Decodable>(_ name: String) -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            fatalError("missing shared resource \(name).json")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            fatalError("cannot decode \(name).json: \(error)")
        }
    }
}
