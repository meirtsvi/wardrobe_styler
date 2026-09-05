// Deterministic rule-based combiner (PLAN §5.6): the last resort after the local and Gemini planners, and the "reused" tier. Mirrors combiner.ts.
import Foundation

public struct Combiner: Sendable {
    private let taxonomy: Taxonomy
    private let rules: TemperatureRules
    private let validator: OutfitValidator

    public init(taxonomy: Taxonomy = .shared, rules: TemperatureRules = .shared, validator: OutfitValidator = OutfitValidator()) {
        self.taxonomy = taxonomy; self.rules = rules; self.validator = validator
    }

    private func sorted(_ cands: [Candidate], _ category: Category) -> [Candidate] {
        cands.filter { $0.category == category }.sorted { $0.score > $1.score }
    }

    private func reason(_ slot: Slot, _ c: Candidate, _ ctx: PlanContext) -> String {
        let w = ctx.wearWindow
        let colour = c.colorName.replacingOccurrences(of: "_", with: " ")
        let sub = c.subcategory.replacingOccurrences(of: "_", with: " ")
        switch slot {
        case .outerwear: return "\(c.warmth.rawValue) layer for \(Int(w.minFeelsLikeC.rounded())) °C"
        case .midLayer: return "mid layer for a \(rules.band(w.minFeelsLikeC)) start"
        case .shoes: return "\(colour) \(sub) for \(ctx.occasion.rawValue)"
        default: return "\(colour) \(sub), \(ctx.occasion.rawValue)-ready"
        }
    }

    private func build(core: [(Slot, Candidate)], cands: [Candidate], ctx: PlanContext) -> PlannedOutfit? {
        let w = ctx.wearWindow
        var slots = core.map { PlannedSlot(slot: $0.0, itemId: $0.1.id, reason: reason($0.0, $0.1, ctx)) }
        var used = Set(core.map { $0.1.id })
        func add(_ slot: Slot, _ item: Candidate?) {
            guard let item, !used.contains(item.id) else { return }
            used.insert(item.id)
            slots.append(PlannedSlot(slot: slot, itemId: item.id, reason: reason(slot, item, ctx)))
        }

        add(.shoes, sorted(cands, .shoes).first)
        if rules.outerwearAllowed(w, occasion: ctx.occasion) {
            let outer = sorted(cands, .outerwear).first { !rules.outerwearForbidden(w, itemWarmth: $0.warmth) }
            if let outer, rules.outerwearRequired(w) || w.minFeelsLikeC < 15 { add(.outerwear, outer) }
        }
        if rules.midLayerAllowed(w) && w.minFeelsLikeC < 15 && !slots.contains(where: { $0.slot == .outerwear }) { add(.midLayer, sorted(cands, .midLayer).first) }

        let limits = taxonomy.limits(for: ctx.accessoryCount)
        add(.bag, sorted(cands, .bag).first)
        var jewelSubs = Set<String>()
        for j in sorted(cands, .jewelry) {
            if jewelSubs.count >= min(limits.jewelry, 2) { break }
            if jewelSubs.contains(j.subcategory) { continue }
            jewelSubs.insert(j.subcategory)
            add(.jewelry, j)
        }
        if limits.accessory > 0 { add(.accessory, sorted(cands, .accessory).first) }

        let byId = Dictionary(uniqueKeysWithValues: cands.map { ($0.id, $0) })
        var colours: [String] = []
        for s in slots { if let c = byId[s.itemId] { let n = c.colorName.replacingOccurrences(of: "_", with: " "); if !colours.contains(n) { colours.append(n) } } }
        let minT = Int(w.minFeelsLikeC.rounded()), maxT = Int(w.maxFeelsLikeC.rounded())
        var outfit = PlannedOutfit(
            slots: slots,
            rationale: "Rule-based pick: \(colours.prefix(3).joined(separator: ", ")) for \(ctx.occasion.rawValue), \(minT)–\(maxT) °C.",
            weatherFit: .acceptable,
            formality: core.first?.1.formality ?? .casual,
            palette: colours,
            layeringNote: rules.spansTwoBands(w) ? "\(minT)° early, \(maxT)° later: shed the outer layer as it warms." : nil,
            confidence: 0.5)

        var result = validator.validate(outfit, candidates: byId, context: ctx)
        for slot in [Slot.accessory, .jewelry, .bag, .midLayer, .outerwear] where !result.passed {
            guard result.rulesFailed.contains(where: { $0.contains(slot.rawValue) }) else { continue }
            outfit.slots.removeAll { $0.slot == slot }
            result = validator.validate(outfit, candidates: byId, context: ctx)
        }
        return result.passed ? outfit : nil
    }

    /// Try one-piece and top+bottom cores in score order; return the first outfit the validator accepts.
    public func combine(_ cands: [Candidate], ctx: PlanContext) -> PlannedOutfit? {
        let anchor = ctx.anchorId.flatMap { id in cands.first { $0.id == id } }
        let tops = sorted(cands, .top), bottoms = sorted(cands, .bottom), onePieces = sorted(cands, .onePiece)

        var cores: [[(Slot, Candidate)]] = []
        func push(_ core: [(Slot, Candidate)]) {
            if let anchor, [Category.top, .bottom, .onePiece].contains(anchor.category), !core.contains(where: { $0.1.id == anchor.id }) { return }
            cores.append(core)
        }
        for op in onePieces { push([(.onePiece, op)]) }
        for t in tops.prefix(4) { for b in bottoms.prefix(4) { push([(.top, t), (.bottom, b)]) } }

        var pool = cands
        if let anchor {
            var boosted = anchor
            boosted.score = .greatestFiniteMagnitude
            pool = [boosted] + cands.filter { $0.id != anchor.id }
        }
        for core in cores {
            if let outfit = build(core: core, cands: pool, ctx: ctx) { return outfit }
        }
        return nil
    }
}
