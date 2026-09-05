// Client mirror of the server validator (PLAN §5.6). Rule ids match backend/src/domain/validator.ts so logs and tests line up.
import Foundation

public struct OutfitValidator: Sendable {
    private let taxonomy: Taxonomy
    private let rules: TemperatureRules
    private let colorWords: [String]

    public init(taxonomy: Taxonomy = .shared, rules: TemperatureRules = .shared, palette: ColorPalette = .shared) {
        self.taxonomy = taxonomy
        self.rules = rules
        self.colorWords = palette.named.keys.map { $0.replacingOccurrences(of: "_", with: " ") }.sorted()
    }

    public func validate(_ outfit: PlannedOutfit, candidates: [String: Candidate], context ctx: PlanContext, advisory: Bool = false) -> ValidationResult {
        var failed: [String] = []
        var warnings: [String] = []
        func fail(_ rule: String) { if !failed.contains(rule) { failed.append(rule) } }

        struct Placed { let slot: Slot; let item: Candidate }
        var items: [Placed] = []
        for s in outfit.slots {
            guard let item = candidates[s.itemId] else { fail("unknown_item:\(s.itemId)"); continue }
            if !taxonomy.slotAccepts(s.slot, category: item.category) { fail("slot_category_mismatch:\(s.slot.rawValue)") }
            items.append(Placed(slot: s.slot, item: item))
        }
        func has(_ slot: Slot) -> Bool { items.contains { $0.slot == slot } }
        func of(_ slot: Slot) -> [Candidate] { items.filter { $0.slot == slot }.map(\.item) }

        for slot in Slot.allCases {
            let entries = of(slot)
            if entries.count > taxonomy.maxItems(in: slot) { fail("duplicate_slot:\(slot.rawValue)") }
            if Set(entries.map(\.subcategory)).count != entries.count { fail("duplicate_subcategory:\(slot.rawValue)") }
        }

        if has(.onePiece) && (has(.bottom) || has(.top) || has(.baseLayer)) { fail("one_piece_conflict") }
        if has(.baseLayer) {
            let top = of(.top).first
            if !(top?.layerRole == .single || top?.layerRole == .mid) { fail("base_layer_without_layerable_top") }
        }
        if !has(.onePiece) && !(has(.top) && has(.bottom)) { fail("missing_top_or_bottom") }
        if has(.outerwear) && !(has(.top) || has(.onePiece)) { fail("outerwear_without_top") }
        if !has(.shoes) { fail("shoes_missing") }

        if let anchor = ctx.anchorId, !items.contains(where: { $0.item.id == anchor }) { fail("anchor_missing") }

        for p in items where !taxonomy.formalityAllowed(p.item.formality, for: ctx.occasion) { fail("formality:\(p.item.id)") }

        let w = ctx.wearWindow
        if rules.outerwearRequired(w) && !has(.outerwear) { fail("outerwear_required") }
        if has(.outerwear) {
            if !rules.outerwearAllowed(w, occasion: ctx.occasion) { fail("outerwear_not_allowed") }
            for o in of(.outerwear) where rules.outerwearForbidden(w, itemWarmth: o.warmth) { fail("outerwear_forbidden") }
        }
        if has(.midLayer) && !rules.midLayerAllowed(w) { fail("mid_layer_not_allowed") }
        if has(.baseLayer) {
            let top = of(.top).first, base = of(.baseLayer).first
            let structural = (top?.layerRole == .single || top?.layerRole == .mid) && base?.layerRole == .base
            if !rules.baseLayerAllowedByTemperature(w) && !structural { fail("base_layer_not_allowed") }
        }
        if rules.heavyForbidden(w) && items.contains(where: { $0.item.warmth == .heavy }) { fail("heavy_warmth_forbidden") }
        let clothing = items.filter { Slot.clothing.contains($0.slot) }
        if rules.lightOnlyForbidden(w) && !clothing.isEmpty && clothing.allSatisfy({ $0.item.warmth == .light }) { fail("light_only_forbidden") }
        for s in of(.shoes) where rules.isOpenShoe(s.subcategory) && !rules.openShoesAllowed(w) { fail("open_shoes_not_allowed") }
        if rules.spansTwoBands(w) && (outfit.layeringNote ?? "").trimmingCharacters(in: .whitespaces).isEmpty { fail("layering_note_missing") }

        let limits = taxonomy.limits(for: ctx.accessoryCount)
        if ctx.accessoryCount == .none && (has(.jewelry) || has(.accessory)) {
            fail("accessories_not_wanted")
        } else {
            if of(.jewelry).count > limits.jewelry { warnings.append("jewelry_over_preference:\(limits.jewelry)") }
            if of(.accessory).count > limits.accessory { warnings.append("accessory_over_preference:\(limits.accessory)") }
        }

        let ids = Set(items.map(\.item.id))
        if ctx.recentOutfits.contains(where: { Set($0) == ids }) { fail("repeat_within_14_days") }
        if ctx.yesterdayItemIds.filter({ ids.contains($0) }).count > taxonomy.history.maxReusedFromYesterday { fail("too_many_from_yesterday") }

        if outfit.rationale.trimmingCharacters(in: .whitespaces).isEmpty { fail("rationale_empty") }
        for s in outfit.slots where s.reason.trimmingCharacters(in: .whitespaces).isEmpty { fail("reason_empty:\(s.slot.rawValue)") }
        let text = ([outfit.rationale] + outfit.slots.map(\.reason) + [outfit.layeringNote ?? ""]).joined(separator: " ")
        let inOutfitColors = Set(items.map { $0.item.colorName.replacingOccurrences(of: "_", with: " ") })
        let inOutfitSubs = Set(items.map { $0.item.subcategory.replacingOccurrences(of: "_", with: " ") })
        for c in colorWords where !inOutfitColors.contains(c) && Self.mentions(text, phrase: c) { fail("rationale_truth:color:\(c)") }
        for sub in Set(taxonomy.allSubcategories.map { $0.replacingOccurrences(of: "_", with: " ") }).sorted()
            where !inOutfitSubs.contains(sub) && Self.mentions(text, phrase: sub) { fail("rationale_truth:item:\(sub)") }

        if advisory { return ValidationResult(passed: true, rulesFailed: [], advisoryWarnings: failed + warnings) }
        return ValidationResult(passed: failed.isEmpty, rulesFailed: failed, advisoryWarnings: warnings)
    }

    static func tokens(_ text: String) -> [String] {
        let lowered = text.lowercased().unicodeScalars.map { scalar -> Character in
            let c = Character(scalar)
            return (c.isLetter && c.isASCII) || c.isNumber || c == "-" || c.isWhitespace ? c : " "
        }
        return String(lowered)
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
            .map { t in t.hasSuffix("s") && t.count > 3 ? String(t.dropLast()) : String(t) }
    }

    /// True when `phrase` appears as consecutive tokens in `text` (crude singularisation on both sides).
    static func mentions(_ text: String, phrase: String) -> Bool {
        let t = tokens(text), p = tokens(phrase)
        guard !p.isEmpty, t.count >= p.count else { return false }
        for i in 0...(t.count - p.count) where Array(t[i..<(i + p.count)]) == p { return true }
        return false
    }
}
