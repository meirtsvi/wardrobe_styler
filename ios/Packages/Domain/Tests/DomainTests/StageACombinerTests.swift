import Foundation
import Testing
@testable import Domain

enum Fixtures {
    static func closet() -> [WardrobeItem] {
        var items: [WardrobeItem] = [
            WardrobeItem(id: "tee-white", category: .top, subcategory: "tee", layerRole: .base, colorHex: "#F7F7F5", colorName: "white", warmth: .light, formality: .casual),
            WardrobeItem(id: "shirt-blue", category: .top, subcategory: "shirt", layerRole: .single, colorHex: "#2F5DA8", colorName: "blue", warmth: .mid),
            WardrobeItem(id: "sweater-grey", category: .top, subcategory: "sweater", layerRole: .single, colorHex: "#8C8C8C", colorName: "grey", material: "wool", warmth: .warm),
            WardrobeItem(id: "jeans-navy", category: .bottom, subcategory: "jeans", colorHex: "#1F2A44", colorName: "navy", material: "denim", formality: .casual),
            WardrobeItem(id: "chinos-tan", category: .bottom, subcategory: "chinos", colorHex: "#C8A97E", colorName: "tan"),
            WardrobeItem(id: "shorts-khaki", category: .bottom, subcategory: "shorts", colorHex: "#B7A97A", colorName: "khaki", warmth: .light, formality: .casual),
            WardrobeItem(id: "dress-black", category: .onePiece, subcategory: "dress", colorHex: "#111111", colorName: "black", warmth: .light),
            WardrobeItem(id: "cardigan-sage", category: .midLayer, subcategory: "cardigan", layerRole: .mid, colorHex: "#9CAF88", colorName: "sage", material: "knit"),
            WardrobeItem(id: "trench-camel", category: .outerwear, subcategory: "trench", colorHex: "#C19A6B", colorName: "camel", warmth: .light),
            WardrobeItem(id: "parka-black", category: .outerwear, subcategory: "parka", colorHex: "#111111", colorName: "black", warmth: .heavy, formality: .casual),
            WardrobeItem(id: "sneakers-white", category: .shoes, subcategory: "sneakers", colorHex: "#F7F7F5", colorName: "white", formality: .casual, quantity: 2),
            WardrobeItem(id: "boots-brown", category: .shoes, subcategory: "boots", colorHex: "#6B4A2B", colorName: "brown", material: "leather", warmth: .warm, quantity: 2),
            WardrobeItem(id: "sandals-tan", category: .shoes, subcategory: "sandals", colorHex: "#C8A97E", colorName: "tan", warmth: .light, formality: .casual, quantity: 2),
            WardrobeItem(id: "tote-black", category: .bag, subcategory: "tote", colorHex: "#111111", colorName: "black", material: "leather"),
            WardrobeItem(id: "necklace-gold", category: .jewelry, subcategory: "necklace", colorHex: "#C9A227", colorName: "gold"),
            WardrobeItem(id: "belt-brown", category: .accessory, subcategory: "belt", colorHex: "#6B4A2B", colorName: "brown", material: "leather"),
        ]
        for i in 1...15 { items.append(WardrobeItem(id: "earrings-\(i)", category: .jewelry, subcategory: "earrings", colorHex: "#BFC4C9", colorName: "silver", quantity: 2)) }
        return items
    }

    static let today = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21
    static func inputs() -> StageAInputs { StageAInputs(today: today, calendarSeason: .autumn) }
    static func ctx(_ w: WearWindow = WearWindow(minFeelsLikeC: 18, maxFeelsLikeC: 21, precipProbMax: 10), occasion: Occasion = .casual,
                    anchor: String? = nil, accessories: AccessoryCount = .some) -> PlanContext {
        PlanContext(occasion: occasion, wearWindow: w, anchorId: anchor, accessoryCount: accessories)
    }
}

@Suite struct StageATests {
    let stageA = StageA()

    @Test func hardFiltersDropUnavailableButKeepReviewQueueAndOffSeason() {
        var closet = Fixtures.closet()
        closet.append(WardrobeItem(id: "laundry-tee", category: .top, subcategory: "tee", availability: .laundry))
        closet.append(WardrobeItem(id: "archived", category: .top, subcategory: "tee", status: .archived))
        closet.append(WardrobeItem(id: "wishlist", category: .top, subcategory: "tee", owned: false))
        closet.append(WardrobeItem(id: "summer-only", category: .top, subcategory: "tee", season: [.summer]))
        closet.append(WardrobeItem(id: "unreviewed", category: .top, subcategory: "tee", status: .new))
        let cands = stageA.run(closet, ctx: Fixtures.ctx(), inputs: Fixtures.inputs())
        let ids = cands.map(\.id)
        for bad in ["laundry-tee", "archived", "wishlist"] { #expect(!ids.contains(bad)) }
        #expect(ids.contains("unreviewed"))
        #expect(ids.contains("summer-only"))
        #expect(cands.first { $0.id == "summer-only" }!.score < cands.first { $0.id == "unreviewed" }!.score)
    }

    @Test func warmDayKeepsLightOuterwearOnly() {
        let ids = stageA.run(Fixtures.closet(), ctx: Fixtures.ctx(WearWindow(minFeelsLikeC: 17, maxFeelsLikeC: 26, precipProbMax: 0)), inputs: Fixtures.inputs()).map(\.id)
        #expect(!ids.contains("parka-black"))
        #expect(ids.contains("trench-camel"))
    }

    @Test func diversityAndCap() {
        let cands = stageA.run(Fixtures.closet(), ctx: Fixtures.ctx(), inputs: Fixtures.inputs())
        #expect(cands.count <= 45)
        let jewelry = cands.filter { $0.category == .jewelry }
        #expect(jewelry.count == 4)
        #expect(Set(jewelry.map(\.subcategory)).count >= 2)
    }

    @Test func fifteenPairsOfEarringsRotate() {
        var closet = Fixtures.closet()
        var seen = Set<String>()
        var day = Fixtures.today
        for _ in 0..<30 {
            let cands = stageA.run(closet, ctx: Fixtures.ctx(), inputs: StageAInputs(today: day, calendarSeason: .autumn))
            if let pick = cands.filter({ $0.subcategory == "earrings" }).max(by: { $0.score < $1.score }) {
                seen.insert(pick.id)
                if let idx = closet.firstIndex(where: { $0.id == pick.id }) { closet[idx].lastSuggestedAt = day }
            }
            day = day.addingTimeInterval(86_400)
        }
        #expect(seen.count >= 10)
    }

    @Test func scoreTermsMatchTheSpec() {
        let fresh = WardrobeItem(id: "f", category: .top, subcategory: "tee")
        let recent = WardrobeItem(id: "r", category: .top, subcategory: "tee", lastSuggestedAt: Fixtures.today.addingTimeInterval(-86_400))
        #expect(stageA.coverageScore(fresh, inputs: Fixtures.inputs()) == 1)
        #expect(abs(stageA.coverageScore(recent, inputs: Fixtures.inputs()) - 1.0 / 14) < 1e-9)
        let disliked = StageAInputs(today: Fixtures.today, calendarSeason: .autumn, feedback: ["f": ItemFeedback(disliked: true)])
        #expect(stageA.feedbackTerm(fresh, inputs: disliked) == -1)
    }
}

@Suite struct CombinerTests {
    let stageA = StageA()
    let combiner = Combiner()
    let validator = OutfitValidator()

    func run(_ ctx: PlanContext, closet: [WardrobeItem] = Fixtures.closet()) -> (PlannedOutfit?, [String: Candidate]) {
        let cands = stageA.run(closet, ctx: ctx, inputs: Fixtures.inputs())
        return (combiner.combine(cands, ctx: ctx), Dictionary(uniqueKeysWithValues: cands.map { ($0.id, $0) }))
    }

    @Test func mildDayPassesValidator() throws {
        let ctx = Fixtures.ctx()
        let (outfit, pool) = run(ctx)
        let o = try #require(outfit)
        let r = validator.validate(o, candidates: pool, context: ctx)
        #expect(r.passed, "\(r.rulesFailed)")
        #expect(o.slots.contains { $0.slot == .shoes })
    }

    @Test func coldMorningHasOuterwearAndLayeringNote() throws {
        let ctx = Fixtures.ctx(WearWindow(minFeelsLikeC: 3, maxFeelsLikeC: 9, precipProbMax: 20))
        let (outfit, pool) = run(ctx)
        let o = try #require(outfit)
        #expect(o.slots.contains { $0.slot == .outerwear })
        #expect(o.layeringNote != nil)
        #expect(validator.validate(o, candidates: pool, context: ctx).passed)
    }

    @Test func hotDayHasNoLayers() throws {
        let ctx = Fixtures.ctx(WearWindow(minFeelsLikeC: 26, maxFeelsLikeC: 32, precipProbMax: 0))
        let o = try #require(run(ctx).0)
        #expect(!o.slots.contains { $0.slot == .outerwear || $0.slot == .midLayer })
    }

    @Test func laundryNeverAppears() throws {
        let closet = Fixtures.closet().map { i -> WardrobeItem in var c = i; if c.id == "jeans-navy" { c.availability = .laundry }; return c }
        let o = try #require(run(Fixtures.ctx(), closet: closet).0)
        #expect(!o.slots.map(\.itemId).contains("jeans-navy"))
    }

    @Test func anchorDressBuildsAroundIt() throws {
        let o = try #require(run(Fixtures.ctx(anchor: "dress-black")).0)
        #expect(o.slots.first { $0.slot == .onePiece }?.itemId == "dress-black")
        #expect(!o.slots.contains { $0.slot == .bottom })
    }

    @Test func noShoesMeansNoOutfit() {
        let closet = [WardrobeItem(id: "t", category: .top, subcategory: "tee"), WardrobeItem(id: "b", category: .bottom, subcategory: "jeans")]
        #expect(run(Fixtures.ctx(), closet: closet).0 == nil)
    }
}

@Suite struct ColorMathTests {
    @Test func deltaEReferencePair() {
        let d = ColorMath.deltaE00(Lab(L: 50, a: 2.6772, b: -79.7751), Lab(L: 50, a: 0, b: -82.7485))
        #expect(abs(d - 2.0425) < 1e-3)
    }
    @Test func nearestNamesAndHarmony() {
        #expect(ColorMath.nearestNamedColor(hex: "#1F2A44").name == "navy")
        #expect(ColorMath.nearestNamedColor(hex: "#C42B2B").name == "red")
        #expect(ColorMath.isNeutral(hex: "#8C8C8C"))
        #expect(ColorMath.harmonyScore(hex: "#2F5DA8", reference: "#1F3F80") == 1.0)
        #expect(ColorMath.harmonyScore(hex: "#2F5DA8", reference: "#E07A2E") == 0.8)
    }
}
