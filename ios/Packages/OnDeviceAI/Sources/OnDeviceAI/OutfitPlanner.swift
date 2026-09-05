// Planner abstraction (ADR 0001): the local Foundation Models planner, the Gemini gateway planner and the combiner all implement it.
import Domain
import Foundation

public struct PlannerViolation: Codable, Equatable, Sendable {
    public var index: Int
    public var rulesFailed: [String]
    public init(index: Int, rulesFailed: [String]) { self.index = index; self.rulesFailed = rulesFailed }
    enum CodingKeys: String, CodingKey { case index, rulesFailed = "rules_failed" }
}

public struct PlannerCall: Sendable {
    public var candidates: [Candidate]
    public var context: PlanContext
    public var n: Int
    public var violations: [PlannerViolation]?
    public var city: String?
    public var learnedRules: [String]
    public var previousOutfits: [PlannedOutfit]

    public init(candidates: [Candidate], context: PlanContext, n: Int = 3, violations: [PlannerViolation]? = nil, city: String? = nil,
                learnedRules: [String] = [], previousOutfits: [PlannedOutfit] = []) {
        self.candidates = candidates; self.context = context; self.n = n; self.violations = violations; self.city = city
        self.learnedRules = learnedRules; self.previousOutfits = previousOutfits
    }
}

public enum PlannerAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)
}

public protocol OutfitPlanner: Sendable {
    var name: String { get }
    func availability() async -> PlannerAvailability
    func plan(_ call: PlannerCall) async throws -> PlanResponse
}

/// Rule-only planner: Stage A candidates → combiner. Always available.
public struct CombinerPlanner: OutfitPlanner {
    public let name = "combiner"
    private let combiner = Combiner()
    public init() {}
    public func availability() async -> PlannerAvailability { .available }
    public func plan(_ call: PlannerCall) async throws -> PlanResponse {
        let outfit = combiner.combine(call.candidates, ctx: call.context)
        return PlanResponse(outfits: outfit.map { [$0] } ?? [], anchorHonored: outfit != nil, anchorReason: outfit == nil ? "no valid combination" : nil)
    }
}

/// Structured user content shared by the local and remote planners (mirrors stageBUserContent in the gateway).
public enum PlannerPayload {
    public struct Weather: Codable { public var wear_window: WearWindow; public var city: String? }
    public struct Body: Codable {
        public var occasion: String
        public var weather: Weather
        public var anchor_id: String?
        public var accessory_count: String
        public var learned_rules: [String]
        public var recent_outfit_item_ids: [[String]]
        public var yesterday_item_ids: [String]
        public var violations: [PlannerViolation]?
        public var previous_outfits: [PlannedOutfit]?
        public var candidates: [CompactCandidate]
    }
    public struct CompactCandidate: Codable {
        public var id: String, category: String, subcategory: String, layer_role: String?, color_name: String, color_hex: String
        public var pattern: String, material: String, warmth: String, formality: String, last_suggested_days: Int?, wear_count: Int, quantity: Int, in_palette: Bool
        init(_ c: Candidate) {
            id = c.id; category = c.category.rawValue; subcategory = c.subcategory; layer_role = c.layerRole?.rawValue; color_name = c.colorName
            color_hex = c.colorHex; pattern = c.pattern; material = c.material; warmth = c.warmth.rawValue; formality = c.formality.rawValue
            last_suggested_days = c.lastSuggestedDays; wear_count = c.wearCount; quantity = c.quantity; in_palette = c.inPalette
        }
    }

    public static func body(for call: PlannerCall) -> Body {
        Body(occasion: call.context.occasion.rawValue,
             weather: Weather(wear_window: call.context.wearWindow, city: call.city),
             anchor_id: call.context.anchorId,
             accessory_count: call.context.accessoryCount.rawValue,
             learned_rules: Array(call.learnedRules.prefix(30)),
             recent_outfit_item_ids: call.context.recentOutfits,
             yesterday_item_ids: call.context.yesterdayItemIds,
             violations: call.violations,
             previous_outfits: call.violations == nil ? nil : call.previousOutfits,
             candidates: call.candidates.map(CompactCandidate.init))
    }

    public static func json(for call: PlannerCall) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return String(decoding: try enc.encode(body(for: call)), as: UTF8.self)
    }
}
