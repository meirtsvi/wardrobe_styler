// Stage A — deterministic candidate retrieval and scoring on device (PLAN §5.6). Mirrors backend/src/domain/stageA.ts.
import Foundation

public struct StageA: Sendable {
    private let taxonomy: Taxonomy
    private let rules: TemperatureRules
    private let palette: ColorPalette

    public init(taxonomy: Taxonomy = .shared, rules: TemperatureRules = .shared, palette: ColorPalette = .shared) {
        self.taxonomy = taxonomy; self.rules = rules; self.palette = palette
    }

    public func passesHardFilters(_ item: WardrobeItem, ctx: PlanContext, inputs: StageAInputs, realCountInCategory: Int) -> Bool {
        if item.id == ctx.anchorId { return true }
        if item.deleted { return false }
        guard item.status == .auto || item.status == .confirmed else { return false }
        guard item.owned, item.availability == .available else { return false }
        if item.isSeed && realCountInCategory >= 3 { return false }
        if !item.season.isEmpty && !item.season.contains(inputs.calendarSeason) { return false }
        if (item.category == .swim || item.category == .underwear) && !taxonomy.occasionAllowsSwimUnderwear.contains(ctx.occasion.rawValue) { return false }
        guard taxonomy.formalityAllowed(item.formality, for: ctx.occasion) else { return false }
        if inputs.bodyAvoid.contains(item.subcategory) || (item.fit.map { inputs.bodyAvoid.contains($0) } ?? false) { return false }
        let w = ctx.wearWindow
        if item.warmth == .heavy && rules.heavyForbidden(w) { return false }
        if item.category == .outerwear && !rules.outerwearAllowed(w, occasion: ctx.occasion) { return false }
        if item.category == .outerwear && rules.outerwearForbidden(w, itemWarmth: item.warmth) { return false }
        if item.category == .midLayer && !rules.midLayerAllowed(w) { return false }
        return true
    }

    public func daysSinceSuggested(_ item: WardrobeItem, today: Date) -> Int? {
        guard let last = item.lastSuggestedAt else { return nil }
        return max(0, Int(today.timeIntervalSince(last) / 86_400))
    }

    public func coverageScore(_ item: WardrobeItem, inputs: StageAInputs) -> Double {
        let full = Double(taxonomy.history.coverageFullDays)
        let days = Double(daysSinceSuggested(item, today: inputs.today) ?? taxonomy.history.coverageFullDays)
        var score = min(1, days / full)
        if let subDays = inputs.recentSubcategorySuggestions[item.subcategory], subDays <= taxonomy.history.subcategoryPenaltyDays { score -= 0.2 }
        if item.quantity >= 2 { score += 0.05 }
        return max(0, min(1, score))
    }

    public func paletteTerm(_ item: WardrobeItem, inputs: StageAInputs, anchorHex: String?) -> Double {
        let refs = anchorHex.map { [$0] } ?? palette.seasonal(inputs.calendarSeason)
        var score = ColorMath.paletteScore(hex: item.colorHex, references: refs, palette: palette)
        if let cs = inputs.colorSeason, let lab = ColorMath.lab(hex: item.colorHex) {
            if cs.bestHex.contains(where: { ColorMath.lab(hex: $0).map { ColorMath.deltaE00(lab, $0) <= 12 } ?? false }) { score += 0.15 }
            if cs.avoidHex.contains(where: { ColorMath.lab(hex: $0).map { ColorMath.deltaE00(lab, $0) <= 12 } ?? false }) { score -= 0.15 }
        }
        return max(0, min(1, score))
    }

    public func feedbackTerm(_ item: WardrobeItem, inputs: StageAInputs) -> Double {
        guard let f = inputs.feedback[item.id] else { return 0 }
        if f.disliked { return -1 }
        let v = 0.2 * Double(f.thumbsUp) + 0.1 * Double(f.starsAbove3) - 0.5 * Double(f.thumbsDownInOccasion)
        return max(-1, min(1, v))
    }

    public func score(_ item: WardrobeItem, inputs: StageAInputs, anchorHex: String?) -> Double {
        0.4 * coverageScore(item, inputs: inputs) + 0.3 * paletteTerm(item, inputs: inputs, anchorHex: anchorHex) + 0.3 * feedbackTerm(item, inputs: inputs)
    }

    public func inSeasonalPalette(_ item: WardrobeItem, inputs: StageAInputs) -> Bool {
        ColorMath.paletteScore(hex: item.colorHex, references: palette.seasonal(inputs.calendarSeason), palette: palette) >= 0.85
    }

    func candidate(_ item: WardrobeItem, inputs: StageAInputs, score: Double) -> Candidate {
        Candidate(id: item.id, category: item.category, subcategory: item.subcategory, layerRole: item.layerRole, colorName: item.colorName,
                  colorHex: item.colorHex, pattern: item.pattern, material: item.material, warmth: item.warmth, formality: item.formality,
                  lastSuggestedDays: daysSinceSuggested(item, today: inputs.today), wearCount: item.wearCount, quantity: item.quantity,
                  inPalette: inSeasonalPalette(item, inputs: inputs), score: score)
    }

    /// Filter, score and take the top N per category with the §5.6 diversity constraints (≤ 45 items, anchor always included).
    public func run(_ items: [WardrobeItem], ctx: PlanContext, inputs: StageAInputs) -> [Candidate] {
        var realCounts: [Category: Int] = [:]
        for it in items where !it.isSeed && !it.deleted && it.owned { realCounts[it.category, default: 0] += 1 }

        let anchor = ctx.anchorId.flatMap { id in items.first { $0.id == id } }
        let anchorHex = anchor?.colorHex

        let scored = items
            .filter { passesHardFilters($0, ctx: ctx, inputs: inputs, realCountInCategory: realCounts[$0.category] ?? 0) }
            .map { (item: $0, score: score($0, inputs: inputs, anchorHex: anchorHex)) }
            .sorted { $0.score > $1.score }

        func byCategory(_ c: Category) -> [(item: WardrobeItem, score: Double)] { scored.filter { $0.item.category == c } }
        let n = TopN.shared
        var picked: [(item: WardrobeItem, score: Double)] = []
        func take(_ c: Category, _ count: Int) { picked.append(contentsOf: byCategory(c).prefix(count)) }

        let tops = byCategory(.top)
        var chosenTops = Array(tops.prefix(n.top))
        let baseCapable = chosenTops.filter { $0.item.layerRole == .base }.count
        if baseCapable < n.topMinBaseCapable {
            let extras = tops.filter { t in t.item.layerRole == .base && !chosenTops.contains { $0.item.id == t.item.id } }.prefix(n.topMinBaseCapable - baseCapable)
            for b in extras {
                if let idx = chosenTops.lastIndex(where: { $0.item.layerRole != .base }) { chosenTops[idx] = b }
            }
        }
        picked.append(contentsOf: chosenTops)
        take(.bottom, n.bottom); take(.onePiece, n.onePiece); take(.midLayer, n.midLayer); take(.outerwear, n.outerwear)
        take(.shoes, n.shoes); take(.bag, n.bag)

        let jewelry = byCategory(.jewelry)
        var chosenJewelry = Array(jewelry.prefix(n.jewelry))
        let subs = Set(chosenJewelry.map(\.item.subcategory))
        if subs.count < n.jewelryMinSubcategories, let other = jewelry.first(where: { !subs.contains($0.item.subcategory) }), !chosenJewelry.isEmpty {
            chosenJewelry[chosenJewelry.count - 1] = other
        }
        picked.append(contentsOf: chosenJewelry)
        take(.accessory, n.accessory)

        if let anchor, !picked.contains(where: { $0.item.id == anchor.id }) {
            picked.insert((anchor, score(anchor, inputs: inputs, anchorHex: anchorHex)), at: 0)
        }

        let lightOnlyBanned = rules.lightOnlyForbidden(ctx.wearWindow)
        let result = picked.filter { p in
            if !lightOnlyBanned || p.item.warmth != .light || p.item.id == anchor?.id { return true }
            return !picked.contains { $0.item.category == p.item.category && $0.item.warmth != .light }
        }
        return result.map { candidate($0.item, inputs: inputs, score: $0.score) }
    }
}

/// shared/schemas/taxonomy.json `stage_a_top_n`.
struct TopN: Decodable, Sendable {
    let top: Int, topMinBaseCapable: Int, bottom: Int, onePiece: Int, midLayer: Int, outerwear: Int, shoes: Int, bag: Int
    let jewelry: Int, jewelryMinSubcategories: Int, accessory: Int
    enum CodingKeys: String, CodingKey {
        case top, bottom, outerwear, shoes, bag, jewelry, accessory
        case topMinBaseCapable = "top_min_base_capable", onePiece = "one_piece", midLayer = "mid_layer", jewelryMinSubcategories = "jewelry_min_subcategories"
    }
    static let shared: TopN = {
        struct Wrapper: Decodable { let stage_a_top_n: TopN }
        let w: Wrapper = SharedResources.decode("taxonomy")
        return w.stage_a_top_n
    }()
}
