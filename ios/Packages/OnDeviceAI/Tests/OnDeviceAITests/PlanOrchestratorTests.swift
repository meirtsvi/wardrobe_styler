import Domain
import Foundation
import Testing
@testable import OnDeviceAI

actor ScriptedPlanner: OutfitPlanner {
    nonisolated let name: String
    private let responses: [Result<PlanResponse, Error>]
    private(set) var calls: [PlannerCall] = []
    private let available: PlannerAvailability
    init(name: String, available: PlannerAvailability = .available, _ responses: [Result<PlanResponse, Error>]) {
        self.name = name; self.responses = responses; self.available = available
    }
    func availability() async -> PlannerAvailability { available }
    func plan(_ call: PlannerCall) async throws -> PlanResponse {
        calls.append(call)
        let r = responses[min(calls.count - 1, responses.count - 1)]
        return try r.get()
    }
}

struct Boom: Error {}

@Suite struct PlanOrchestratorTests {
    static func closet() -> [WardrobeItem] {
        [
            WardrobeItem(id: "shirt-blue", category: .top, subcategory: "shirt", layerRole: .single, colorHex: "#2F5DA8", colorName: "blue"),
            WardrobeItem(id: "tee-white", category: .top, subcategory: "tee", layerRole: .base, colorHex: "#F7F7F5", colorName: "white", warmth: .light, formality: .casual),
            WardrobeItem(id: "jeans-navy", category: .bottom, subcategory: "jeans", colorHex: "#1F2A44", colorName: "navy", formality: .casual),
            WardrobeItem(id: "dress-black", category: .onePiece, subcategory: "dress", colorHex: "#111111", colorName: "black"),
            WardrobeItem(id: "sneakers-white", category: .shoes, subcategory: "sneakers", colorHex: "#F7F7F5", colorName: "white", formality: .casual),
            WardrobeItem(id: "trench-camel", category: .outerwear, subcategory: "trench", colorHex: "#C19A6B", colorName: "camel", warmth: .light),
        ]
    }
    static let ctx = PlanContext(occasion: .casual, wearWindow: WearWindow(minFeelsLikeC: 18, maxFeelsLikeC: 21, precipProbMax: 10))
    static let inputs = StageAInputs(today: Date(timeIntervalSince1970: 1_790_000_000), calendarSeason: .autumn)

    static let good = PlannedOutfit(slots: [PlannedSlot(slot: .top, itemId: "shirt-blue", reason: "blue shirt"), PlannedSlot(slot: .bottom, itemId: "jeans-navy", reason: "navy jeans"), PlannedSlot(slot: .shoes, itemId: "sneakers-white", reason: "white sneakers")], rationale: "Analogous blues for a mild day.")
    static let bad = PlannedOutfit(slots: [PlannedSlot(slot: .onePiece, itemId: "dress-black", reason: "black dress"), PlannedSlot(slot: .bottom, itemId: "jeans-navy", reason: "navy jeans"), PlannedSlot(slot: .shoes, itemId: "sneakers-white", reason: "white sneakers")], rationale: "Black dress with jeans.")

    @Test func localPlannerAcceptedFirstPass() async {
        let local = ScriptedPlanner(name: "local", [.success(PlanResponse(outfits: [Self.good], anchorHonored: true, anchorReason: nil))])
        let remote = ScriptedPlanner(name: "remote", [.success(PlanResponse(outfits: [Self.good], anchorHonored: true, anchorReason: nil))])
        let out = await PlanOrchestrator(planners: [local, remote]).plan(items: Self.closet(), context: Self.ctx, inputs: Self.inputs)
        #expect(out.calls == ["local": 1])
        #expect(out.outfits.first?.plannerName == "local")
        #expect(await remote.calls.isEmpty)
    }

    @Test func repairCarriesViolationsAndPreviousOutfits() async {
        let local = ScriptedPlanner(name: "local", [
            .success(PlanResponse(outfits: [Self.bad], anchorHonored: true, anchorReason: nil)),
            .success(PlanResponse(outfits: [Self.good], anchorHonored: true, anchorReason: nil)),
        ])
        let out = await PlanOrchestrator(planners: [local]).plan(items: Self.closet(), context: Self.ctx, inputs: Self.inputs)
        #expect(out.calls == ["local": 2])
        let second = await local.calls[1]
        #expect(second.violations == [PlannerViolation(index: 0, rulesFailed: ["one_piece_conflict"])])
        #expect(second.previousOutfits == [Self.bad])
        #expect(out.outfits.first?.repaired == true)
    }

    @Test func unavailableLocalFallsToRemoteThenCombiner() async {
        let local = ScriptedPlanner(name: "local", available: .unavailable(reason: "appleIntelligenceNotEnabled"), [])
        let remote = ScriptedPlanner(name: "remote", [.failure(Boom())])
        let out = await PlanOrchestrator(planners: [local, remote]).plan(items: Self.closet(), context: Self.ctx, inputs: Self.inputs)
        #expect(out.calls.isEmpty)
        #expect(out.outfits.count == 1)
        #expect(out.outfits[0].fallback && out.outfits[0].plannerName == "combiner")
    }

    @Test func localInvalidTwiceThenRemoteSucceeds() async {
        let local = ScriptedPlanner(name: "local", [.success(PlanResponse(outfits: [Self.bad], anchorHonored: true, anchorReason: nil))])
        let remote = ScriptedPlanner(name: "remote", [.success(PlanResponse(outfits: [Self.good], anchorHonored: true, anchorReason: nil))])
        let out = await PlanOrchestrator(planners: [local, remote]).plan(items: Self.closet(), context: Self.ctx, inputs: Self.inputs)
        #expect(out.calls == ["local": 2, "remote": 1])
        #expect(out.outfits.first?.plannerName == "remote")
    }

    @Test func payloadIsStructuredData() throws {
        let call = PlannerCall(candidates: StageA().run(Self.closet(), ctx: Self.ctx, inputs: Self.inputs), context: Self.ctx, n: 3, city: "Tel Aviv")
        let json = try PlannerPayload.json(for: call)
        #expect(json.contains("\"wear_window\""))
        #expect(json.contains("\"city\":\"Tel Aviv\""))
        #expect(!json.contains("\"score\""))
    }

    @Test func instructionsEmbedPersonaAndRules() {
        let s = Prompts.stageBInstructions()
        #expect(s.contains("You are Remy"))
        #expect(s.contains("[outerwear_required]"))
        #expect(s.contains("work: business or smart_casual"))
    }

    @Test func localPlannerReportsAvailabilityWithoutCrashing() async {
        // On CI/macOS without Apple Intelligence this is .unavailable; on a provisioned device it is .available. Either is fine.
        let a = await LocalPlanner().availability()
        switch a {
        case .available, .unavailable: #expect(Bool(true))
        }
    }
}
