// Stage A → local planner → validator → one repair → remote (Gemini) planner → combiner (ADR 0001, PLAN §5.6). The card always renders.
import Domain
import Foundation

public struct PlannedResult: Equatable, Sendable {
    public var outfit: PlannedOutfit
    public var passed: Bool
    public var rulesFailed: [String]
    public var repaired: Bool
    public var fallback: Bool
    public var plannerName: String
    public var advisoryWarnings: [String]
}

public struct PlanOutcome: Sendable {
    public var outfits: [PlannedResult]
    public var candidates: [Candidate]
    public var anchorHonored: Bool
    public var anchorReason: String?
    /// planner name → calls made
    public var calls: [String: Int]
}

public struct PlanOrchestrator: Sendable {
    private let stageA: StageA
    private let validator: OutfitValidator
    private let combiner: Combiner
    /// Tried in order: e.g. [LocalPlanner, GatewayPlanner]. Each gets one plan call and one repair call.
    private let planners: [any OutfitPlanner]

    public init(planners: [any OutfitPlanner], stageA: StageA = StageA(), validator: OutfitValidator = OutfitValidator(), combiner: Combiner = Combiner()) {
        self.planners = planners; self.stageA = stageA; self.validator = validator; self.combiner = combiner
    }

    public func plan(items: [WardrobeItem], context ctx: PlanContext, inputs: StageAInputs, n: Int = 3,
                     city: String? = nil, learnedRules: [String] = []) async -> PlanOutcome {
        let candidates = stageA.run(items, ctx: ctx, inputs: inputs)
        let byId = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        var calls: [String: Int] = [:]
        var results: [PlannedResult] = []
        var anchorReason: String? = nil

        for planner in planners {
            guard await planner.availability() == .available else { continue }
            var call = PlannerCall(candidates: candidates, context: ctx, n: n, city: city, learnedRules: learnedRules)
            guard let first = try? await planner.plan(call) else { continue }
            calls[planner.name, default: 0] += 1
            anchorReason = first.anchorReason

            var attempt = first.outfits.map { o -> PlannedResult in
                let v = validator.validate(o, candidates: byId, context: ctx)
                return PlannedResult(outfit: o, passed: v.passed, rulesFailed: v.rulesFailed, repaired: false, fallback: false, plannerName: planner.name, advisoryWarnings: v.advisoryWarnings)
            }
            let violations = attempt.enumerated().filter { !$0.element.passed }.map { PlannerViolation(index: $0.offset, rulesFailed: $0.element.rulesFailed) }
            if !violations.isEmpty {
                call.violations = violations
                call.previousOutfits = first.outfits
                if let repaired = try? await planner.plan(call) {
                    calls[planner.name, default: 0] += 1
                    for v in violations where v.index < repaired.outfits.count {
                        let o = repaired.outfits[v.index]
                        let check = validator.validate(o, candidates: byId, context: ctx)
                        attempt[v.index] = PlannedResult(outfit: o, passed: check.passed, rulesFailed: check.rulesFailed, repaired: true, fallback: false, plannerName: planner.name, advisoryWarnings: check.advisoryWarnings)
                    }
                    if repaired.anchorHonored { anchorReason = nil }
                }
            }
            results = attempt.filter(\.passed)
            if !results.isEmpty { break }
        }

        if results.isEmpty, let fallback = combiner.combine(candidates, ctx: ctx) {
            results = [PlannedResult(outfit: fallback, passed: true, rulesFailed: [], repaired: false, fallback: true, plannerName: "combiner", advisoryWarnings: [])]
        }

        let anchorHonored = ctx.anchorId.map { id in results.contains { $0.outfit.slots.contains { $0.itemId == id } } } ?? true
        return PlanOutcome(outfits: Array(results.prefix(n)), candidates: candidates, anchorHonored: anchorHonored,
                           anchorReason: anchorHonored ? nil : (anchorReason ?? "anchor could not be placed"), calls: calls)
    }
}
