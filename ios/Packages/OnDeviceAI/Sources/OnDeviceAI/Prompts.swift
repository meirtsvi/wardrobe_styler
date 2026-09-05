// Shared instruction text for the local Stage B planner (ADR 0001). The gateway builds the equivalent for Gemini from the same shared files.
import Domain
import Foundation

public enum Prompts {
    public static let persona: String = {
        guard let url = Bundle.module.url(forResource: "persona_v1", withExtension: "md"), let s = try? String(contentsOf: url, encoding: .utf8) else {
            return "You are Remy, the user's personal stylist. Be direct, specific and never flattering. Never invent items the user does not own."
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }()

    /// Instructions for the on-device model: persona + slot rules + the shared temperature table. Kept compact for the ~4k-token window.
    public static func stageBInstructions(taxonomy: Taxonomy = .shared, rules: TemperatureRules = .shared) -> String {
        let occasions = taxonomy.occasionFormality.keys.sorted().map { "\($0): \((taxonomy.occasionFormality[$0] ?? []).joined(separator: " or "))" }.joined(separator: "; ")
        return [
            persona,
            "",
            "Task: choose outfits from the candidate items only. Use item ids exactly as given. Never invent items.",
            "Slots: \(taxonomy.slots.joined(separator: ", ")). One item per slot, except jewelry (up to \(taxonomy.maxItems(in: .jewelry))) and accessory (up to \(taxonomy.maxItems(in: .accessory))) with distinct subcategories.",
            "one_piece forbids top, base_layer and bottom; otherwise a top and a bottom are both required. base_layer only under a top whose layer_role is single or mid. outerwear needs a top or one_piece. Shoes are always required.",
            "If an anchor item is given it must appear; if impossible set anchorHonored=false and explain in anchorReason.",
            "Dress code: \(occasions). Items may be one formality step from the occasion's first target; athletic only for sport or gym.",
            "accessory_count: none → no jewelry or accessory; some → 1–2 jewelry, ≤ 1 accessory; many → 2–3 jewelry, 1–2 accessories.",
            "Do not repeat an outfit from recent_outfit_item_ids; reuse at most 2 items from yesterday_item_ids. Prefer high last_suggested_days and rotate subcategories.",
            "",
            rules.renderedText,
            "",
            "Colour: name the harmony rule (monochrome, analogous, complementary, neutral + accent). Rationale ≤ 160 characters citing the colour rule and the weather; each slot reason ≤ 60 characters; mention only colours and items in the outfit.",
            "If violations are given, fix exactly those outfits and keep the rest.",
        ].joined(separator: "\n")
    }
}
