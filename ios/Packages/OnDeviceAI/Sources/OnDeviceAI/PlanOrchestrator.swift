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
    public init(outfit: PlannedOutfit, passed: Bool, rulesFailed: [String], repaired: Bool, fallback: Bool, plannerName: String, advisoryWarnings: [String]) {
        self.outfit = outfit; self.passed = passed; self.rulesFailed = rulesFailed; self.repaired = repaired
        self.fallback = fallback; self.plannerName = plannerName; self.advisoryWarnings = advisoryWarnings
    }
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
    /// A stalled model must never hold the card (PLAN §4.5 "another look" p50 ≤ 4 s; the simulator showed a 20 s Foundation Models stall).
    private let availabilityTimeout: Duration
    private let planTimeout: Duration

    public init(planners: [any OutfitPlanner], stageA: StageA = StageA(), validator: OutfitValidator = OutfitValidator(), combiner: Combiner = Combiner(),
                availabilityTimeout: Duration = .seconds(3), planTimeout: Duration = .seconds(12)) {
        self.planners = planners; self.stageA = stageA; self.validator = validator; self.combiner = combiner
        self.availabilityTimeout = availabilityTimeout; self.planTimeout = planTimeout
    }

    public func plan(items: [WardrobeItem], context ctx: PlanContext, inputs: StageAInputs, n: Int = 3,
                     city: String? = nil, learnedRules: [String] = []) async -> PlanOutcome {
        let candidates = stageA.run(items, ctx: ctx, inputs: inputs)
        let byId = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        var calls: [String: Int] = [:]
        var results: [PlannedResult] = []
        var anchorReason: String? = nil

        for planner in planners {
            let available = (try? await withTimeout(availabilityTimeout) { await planner.availability() }) ?? .unavailable(reason: "availability timeout")
            guard available == .available else { continue }
            let call = PlannerCall(candidates: candidates, context: ctx, n: n, city: city, learnedRules: learnedRules)
            guard let first = try? await withTimeout(planTimeout, { try await planner.plan(call) }) else { continue }
            calls[planner.name, default: 0] += 1
            anchorReason = first.anchorReason

            var attempt = first.outfits.map { o -> PlannedResult in
                let v = validator.validate(o, candidates: byId, context: ctx)
                return PlannedResult(outfit: o, passed: v.passed, rulesFailed: v.rulesFailed, repaired: false, fallback: false, plannerName: planner.name, advisoryWarnings: v.advisoryWarnings)
            }
            let violations = attempt.enumerated().filter { !$0.element.passed }.map { PlannerViolation(index: $0.offset, rulesFailed: $0.element.rulesFailed) }
            if !violations.isEmpty {
                var repairCall = call
                repairCall.violations = violations
                repairCall.previousOutfits = first.outfits
                let repairRequest = repairCall
                if let repaired = try? await withTimeout(planTimeout, { try await planner.plan(repairRequest) }) {
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

public struct PlannerTimeout: Error, Equatable, Sendable {}

/// Runs `operation` and throws PlannerTimeout if it does not finish within `limit`; the operation task is cancelled.
public func withTimeout<T: Sendable>(_ limit: Duration, _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask { try await Task.sleep(for: limit); throw PlannerTimeout() }
        guard let first = try await group.next() else { throw PlannerTimeout() }
        group.cancelAll()
        return first
    }
}
