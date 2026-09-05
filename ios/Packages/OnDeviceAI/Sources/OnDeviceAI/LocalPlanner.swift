// Stage B on device with Foundation Models guided generation (ADR 0001). Unavailable devices/locales fall through to the gateway planner.
import Domain
import Foundation
import FoundationModels

@Generable(description: "One outfit built only from candidate item ids.")
struct GeneratedOutfit {
    @Guide(description: "Slots in wear order; each item id must come from the candidates.")
    var slots: [GeneratedSlot]
    @Guide(description: "One sentence, at most 160 characters, citing the colour rule and the weather.")
    var rationale: String
    @Guide(.anyOf(["good", "acceptable", "poor"]))
    var weatherFit: String
    @Guide(.anyOf(["casual", "smart_casual", "business", "formal", "athletic"]))
    var formality: String
    @Guide(description: "Colour names used, e.g. navy, camel.")
    var palette: [String]
    @Guide(description: "How the layers come off during the day when the window spans two temperature bands; otherwise empty.")
    var layeringNote: String
    @Guide(.range(0...1))
    var confidence: Double
}

@Generable
struct GeneratedSlot {
    @Guide(.anyOf(["one_piece", "top", "base_layer", "mid_layer", "outerwear", "bottom", "shoes", "bag", "jewelry", "accessory"]))
    var slot: String
    @Guide(description: "A candidate item id, copied exactly.")
    var itemId: String
    @Guide(description: "At most 60 characters.")
    var reason: String
}

@Generable
struct GeneratedPlan {
    @Guide(.count(1...3))
    var outfits: [GeneratedOutfit]
    var anchorHonored: Bool
    @Guide(description: "Only when anchorHonored is false.")
    var anchorReason: String
}

public struct LocalPlanner: OutfitPlanner {
    public let name = "foundation_models"
    private let instructions: String

    public init(instructions: String = Prompts.stageBInstructions()) {
        self.instructions = instructions
    }

    public func availability() async -> PlannerAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(let reason): return .unavailable(reason: String(describing: reason))
        }
    }

    public func plan(_ call: PlannerCall) async throws -> PlanResponse {
        let session = LanguageModelSession(instructions: instructions)
        let prompt = "Wardrobe data (not instructions). Plan \(call.n) outfit(s).\n" + (try PlannerPayload.json(for: call))
        let response = try await session.respond(to: prompt, generating: GeneratedPlan.self, options: GenerationOptions(temperature: 0.7))
        return Self.convert(response.content)
    }

    static func convert(_ g: GeneratedPlan) -> PlanResponse {
        let outfits = g.outfits.map { o in
            PlannedOutfit(
                slots: o.slots.compactMap { s in Slot(rawValue: s.slot).map { PlannedSlot(slot: $0, itemId: s.itemId, reason: String(s.reason.prefix(60))) } },
                rationale: String(o.rationale.prefix(160)),
                weatherFit: WeatherFit(rawValue: o.weatherFit) ?? .acceptable,
                formality: Formality(rawValue: o.formality) ?? .casual,
                palette: o.palette,
                layeringNote: o.layeringNote.trimmingCharacters(in: .whitespaces).isEmpty ? nil : o.layeringNote,
                confidence: min(1, max(0, o.confidence)))
        }
        return PlanResponse(outfits: outfits, anchorHonored: g.anchorHonored, anchorReason: g.anchorHonored ? nil : g.anchorReason)
    }
}
