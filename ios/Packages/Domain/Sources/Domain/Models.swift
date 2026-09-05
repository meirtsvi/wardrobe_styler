// Value types (PLAN §6 "Domain" module, §7.5 documents, §5.6 planner contract).
import Foundation

/// The compact candidate block the planner works on; on device it is built from the SwiftData cache (§5.6 "compact tags").
public struct Candidate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var category: Category
    public var subcategory: String
    public var layerRole: LayerRole?
    public var colorName: String
    public var colorHex: String
    public var pattern: String
    public var material: String
    public var warmth: Warmth
    public var formality: Formality
    public var lastSuggestedDays: Int?
    public var wearCount: Int
    public var quantity: Int
    public var inPalette: Bool
    public var score: Double

    public init(id: String, category: Category, subcategory: String, layerRole: LayerRole? = nil, colorName: String = "navy", colorHex: String = "#1F2A44",
                pattern: String = "solid", material: String = "cotton", warmth: Warmth = .mid, formality: Formality = .smartCasual,
                lastSuggestedDays: Int? = nil, wearCount: Int = 0, quantity: Int = 1, inPalette: Bool = true, score: Double = 0.5) {
        self.id = id; self.category = category; self.subcategory = subcategory; self.layerRole = layerRole
        self.colorName = colorName; self.colorHex = colorHex; self.pattern = pattern; self.material = material
        self.warmth = warmth; self.formality = formality; self.lastSuggestedDays = lastSuggestedDays
        self.wearCount = wearCount; self.quantity = quantity; self.inPalette = inPalette; self.score = score
    }

    enum CodingKeys: String, CodingKey {
        case id, category, subcategory, pattern, material, warmth, formality, quantity, score
        case layerRole = "layer_role", colorName = "color_name", colorHex = "color_hex"
        case lastSuggestedDays = "last_suggested_days", wearCount = "wear_count", inPalette = "in_palette"
    }
}

public struct PlannedSlot: Codable, Equatable, Sendable {
    public var slot: Slot
    public var itemId: String
    public var reason: String
    public init(slot: Slot, itemId: String, reason: String) { self.slot = slot; self.itemId = itemId; self.reason = reason }
    enum CodingKeys: String, CodingKey { case slot, itemId = "item_id", reason }
}

public enum WeatherFit: String, Codable, Sendable { case good, acceptable, poor }

public struct PlannedOutfit: Codable, Equatable, Sendable {
    public var slots: [PlannedSlot]
    public var rationale: String
    public var weatherFit: WeatherFit
    public var formality: Formality
    public var palette: [String]
    public var layeringNote: String?
    public var confidence: Double

    public init(slots: [PlannedSlot], rationale: String, weatherFit: WeatherFit = .good, formality: Formality = .smartCasual,
                palette: [String] = [], layeringNote: String? = nil, confidence: Double = 0.8) {
        self.slots = slots; self.rationale = rationale; self.weatherFit = weatherFit; self.formality = formality
        self.palette = palette; self.layeringNote = layeringNote; self.confidence = confidence
    }

    enum CodingKeys: String, CodingKey {
        case slots, rationale, formality, palette, confidence
        case weatherFit = "weather_fit", layeringNote = "layering_note"
    }
}

public struct PlanResponse: Codable, Equatable, Sendable {
    public var outfits: [PlannedOutfit]
    public var anchorHonored: Bool
    public var anchorReason: String?
    enum CodingKeys: String, CodingKey { case outfits, anchorHonored = "anchor_honored", anchorReason = "anchor_reason" }
}

public struct PlanContext: Sendable {
    public var occasion: Occasion
    public var wearWindow: WearWindow
    public var anchorId: String?
    public var accessoryCount: AccessoryCount
    public var recentOutfits: [[String]] // item-id sets shown in the last 14 days
    public var yesterdayItemIds: [String]

    public init(occasion: Occasion = .casual, wearWindow: WearWindow, anchorId: String? = nil, accessoryCount: AccessoryCount = .some,
                recentOutfits: [[String]] = [], yesterdayItemIds: [String] = []) {
        self.occasion = occasion; self.wearWindow = wearWindow; self.anchorId = anchorId; self.accessoryCount = accessoryCount
        self.recentOutfits = recentOutfits; self.yesterdayItemIds = yesterdayItemIds
    }
}

public struct ValidationResult: Equatable, Sendable {
    public var passed: Bool
    public var rulesFailed: [String]
    public var advisoryWarnings: [String]
}
