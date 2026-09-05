import Foundation
import Testing
@testable import Domain

@Suite struct OutfitValidatorTests {
    let v = OutfitValidator()

    let top = Candidate(id: "shirt", category: .top, subcategory: "shirt", layerRole: .single, colorName: "blue", colorHex: "#2F5DA8")
    let tee = Candidate(id: "tee", category: .top, subcategory: "tee", layerRole: .base, colorName: "white", colorHex: "#F7F7F5", warmth: .light)
    let bottom = Candidate(id: "jeans", category: .bottom, subcategory: "jeans", colorName: "navy")
    let shoes = Candidate(id: "sneakers", category: .shoes, subcategory: "sneakers", colorName: "white", colorHex: "#F7F7F5")
    let sandals = Candidate(id: "sandals", category: .shoes, subcategory: "sandals", colorName: "tan", warmth: .light)
    let dress = Candidate(id: "dress", category: .onePiece, subcategory: "dress", colorName: "black")
    let trench = Candidate(id: "trench", category: .outerwear, subcategory: "trench", colorName: "camel", warmth: .light)
    let parka = Candidate(id: "parka", category: .outerwear, subcategory: "parka", colorName: "black", warmth: .heavy)
    let cardigan = Candidate(id: "cardigan", category: .midLayer, subcategory: "cardigan", layerRole: .mid, colorName: "sage")
    let earrings1 = Candidate(id: "e1", category: .jewelry, subcategory: "earrings", colorName: "silver")
    let earrings2 = Candidate(id: "e2", category: .jewelry, subcategory: "earrings", colorName: "silver")
    let necklace = Candidate(id: "n1", category: .jewelry, subcategory: "necklace", colorName: "gold")
    let gymTee = Candidate(id: "gym-tee", category: .top, subcategory: "tee", layerRole: .base, colorName: "black", formality: .athletic)

    var pool: [String: Candidate] {
        Dictionary(uniqueKeysWithValues: [top, tee, bottom, shoes, sandals, dress, trench, parka, cardigan, earrings1, earrings2, necklace, gymTee].map { ($0.id, $0) })
    }

    func outfit(_ slots: [(Slot, Candidate)], rationale: String = "Navy and blue, analogous, for a mild day.", layeringNote: String? = nil) -> PlannedOutfit {
        PlannedOutfit(slots: slots.map { PlannedSlot(slot: $0.0, itemId: $0.1.id, reason: "\($0.1.colorName) \($0.1.subcategory)") },
                      rationale: rationale, layeringNote: layeringNote)
    }

    func ctx(_ w: WearWindow = WearWindow(minFeelsLikeC: 18, maxFeelsLikeC: 21, precipProbMax: 10), occasion: Occasion = .casual,
             anchor: String? = nil, accessories: AccessoryCount = .some, recent: [[String]] = [], yesterday: [String] = []) -> PlanContext {
        PlanContext(occasion: occasion, wearWindow: w, anchorId: anchor, accessoryCount: accessories, recentOutfits: recent, yesterdayItemIds: yesterday)
    }

    @Test func plainOutfitPasses() {
        let r = v.validate(outfit([(.top, top), (.bottom, bottom), (.shoes, shoes)]), candidates: pool, context: ctx())
        #expect(r == ValidationResult(passed: true, rulesFailed: [], advisoryWarnings: []))
    }

    @Test func structuralRules() {
        let r = v.validate(outfit([(.onePiece, dress), (.bottom, bottom)]), candidates: pool, context: ctx())
        #expect(r.rulesFailed.contains("one_piece_conflict"))
        #expect(r.rulesFailed.contains("shoes_missing"))
        let dup = v.validate(outfit([(.top, top), (.bottom, bottom), (.shoes, shoes), (.jewelry, earrings1), (.jewelry, earrings2)]), candidates: pool, context: ctx())
        #expect(dup.rulesFailed.contains("duplicate_subcategory:jewelry"))
        let ok = v.validate(outfit([(.top, top), (.bottom, bottom), (.shoes, shoes), (.jewelry, earrings1), (.jewelry, necklace)]), candidates: pool, context: ctx())
        #expect(ok.passed)
        let base = v.validate(outfit([(.top, tee), (.baseLayer, tee), (.bottom, bottom), (.shoes, shoes)]), candidates: pool, context: ctx())
        #expect(base.rulesFailed.contains("base_layer_without_layerable_top"))
        let ghost = v.validate(outfit([(.top, Candidate(id: "ghost", category: .top, subcategory: "tee")), (.bottom, bottom), (.shoes, shoes)]), candidates: pool, context: ctx())
        #expect(ghost.rulesFailed.contains("unknown_item:ghost"))
    }

    @Test func anchorAndFormality() {
        #expect(v.validate(outfit([(.top, top), (.bottom, bottom), (.shoes, shoes)]), candidates: pool, context: ctx(anchor: "dress")).rulesFailed.contains("anchor_missing"))
        #expect(v.validate(outfit([(.top, gymTee), (.bottom, bottom), (.shoes, shoes)]), candidates: pool, context: ctx(occasion: .work)).rulesFailed.contains("formality:gym-tee"))
    }

    @Test func temperatureTable() {
        let cold = ctx(WearWindow(minFeelsLikeC: 5, maxFeelsLikeC: 7, precipProbMax: 0))
        #expect(v.validate(outfit([(.top, tee), (.bottom, bottom), (.shoes, shoes)]), candidates: pool, context: cold).rulesFailed.contains("outerwear_required"))

        let shoulder = ctx(WearWindow(minFeelsLikeC: 9, maxFeelsLikeC: 21, precipProbMax: 10))
        let layered: [(Slot, Candidate)] = [(.top, top), (.bottom, bottom), (.shoes, shoes), (.outerwear, trench)]
        #expect(v.validate(outfit(layered, layeringNote: "9° at 8 am, 21° by lunch — the trench comes off"), candidates: pool, context: shoulder).passed)
        #expect(v.validate(outfit(layered), candidates: pool, context: shoulder).rulesFailed.contains("layering_note_missing"))

        let warm = ctx(WearWindow(minFeelsLikeC: 17, maxFeelsLikeC: 25, precipProbMax: 0))
        let r = v.validate(outfit([(.top, top), (.bottom, bottom), (.shoes, shoes), (.outerwear, parka)]), candidates: pool, context: warm)
        #expect(r.rulesFailed.contains("heavy_warmth_forbidden"))
        #expect(r.rulesFailed.contains("outerwear_forbidden"))

        let hot = ctx(WearWindow(minFeelsLikeC: 23, maxFeelsLikeC: 30, precipProbMax: 0))
        let h = v.validate(outfit([(.top, top), (.bottom, bottom), (.shoes, shoes), (.midLayer, cardigan), (.outerwear, trench)]), candidates: pool, context: hot)
        #expect(h.rulesFailed.contains("mid_layer_not_allowed"))
        #expect(h.rulesFailed.contains("outerwear_not_allowed"))

        let rainy = ctx(WearWindow(minFeelsLikeC: 18, maxFeelsLikeC: 24, precipProbMax: 70))
        #expect(v.validate(outfit([(.top, top), (.bottom, bottom), (.shoes, sandals)]), candidates: pool, context: rainy).rulesFailed.contains("open_shoes_not_allowed"))
    }

    @Test func preferencesHistoryAndText() {
        let slots: [(Slot, Candidate)] = [(.top, top), (.bottom, bottom), (.shoes, shoes)]
        #expect(v.validate(outfit(slots + [(.jewelry, necklace)]), candidates: pool, context: ctx(accessories: .none)).rulesFailed.contains("accessories_not_wanted"))
        #expect(v.validate(outfit(slots), candidates: pool, context: ctx(recent: [["shirt", "jeans", "sneakers"]])).rulesFailed.contains("repeat_within_14_days"))
        #expect(v.validate(outfit(slots), candidates: pool, context: ctx(yesterday: ["shirt", "jeans", "sneakers"])).rulesFailed.contains("too_many_from_yesterday"))
        #expect(v.validate(outfit(slots), candidates: pool, context: ctx(yesterday: ["shirt", "jeans"])).passed)

        let lying = v.validate(outfit(slots, rationale: "The camel trench warms up the navy jeans."), candidates: pool, context: ctx())
        #expect(lying.rulesFailed.contains("rationale_truth:color:camel"))
        #expect(lying.rulesFailed.contains("rationale_truth:item:trench"))
        // "comes off" + "white" must not read as "off white".
        let honest = v.validate(outfit(slots, rationale: "White sneakers keep it easy; the day comes off relaxed."), candidates: pool, context: ctx())
        #expect(honest.passed, "\(honest.rulesFailed)")

        let advisory = v.validate(outfit([(.onePiece, dress), (.bottom, bottom)]), candidates: pool, context: ctx(), advisory: true)
        #expect(advisory.passed)
        #expect(advisory.advisoryWarnings.contains("one_piece_conflict"))
    }

    @Test func decodesTheGatewayPlanShape() throws {
        let json = """
        {"outfits":[{"slots":[{"slot":"top","item_id":"shirt","reason":"blue shirt"},{"slot":"bottom","item_id":"jeans","reason":"navy jeans"},{"slot":"shoes","item_id":"sneakers","reason":"white sneakers"}],
        "rationale":"Navy and blue, analogous.","weather_fit":"good","formality":"smart_casual","palette":["navy","blue"],"layering_note":null,"confidence":0.8}],
        "anchor_honored":true,"anchor_reason":null}
        """
        let plan = try JSONDecoder().decode(PlanResponse.self, from: Data(json.utf8))
        #expect(plan.outfits.count == 1)
        #expect(v.validate(plan.outfits[0], candidates: pool, context: ctx()).passed)
    }
}
