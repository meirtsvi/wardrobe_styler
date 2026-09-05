import Testing
@testable import Domain

@Suite struct TemperatureRulesTests {
    let rules = TemperatureRules.shared

    @Test func bandsMatchThePlan() {
        #expect(rules.band(-3) == "cold")
        #expect(rules.band(7.9) == "cold")
        #expect(rules.band(8) == "cool")
        #expect(rules.band(15) == "mild")
        #expect(rules.band(22) == "warm")
        #expect(rules.band(28) == "hot")
        #expect(rules.spansTwoBands(WearWindow(minFeelsLikeC: 9, maxFeelsLikeC: 21, precipProbMax: 0)))
        #expect(!rules.spansTwoBands(WearWindow(minFeelsLikeC: 16, maxFeelsLikeC: 21, precipProbMax: 0)))
    }

    @Test func outerwearRequiredAllowedForbidden() {
        #expect(rules.outerwearRequired(WearWindow(minFeelsLikeC: 7, maxFeelsLikeC: 12, precipProbMax: 0)))
        #expect(rules.outerwearRequired(WearWindow(minFeelsLikeC: 12, maxFeelsLikeC: 18, precipProbMax: 60)))
        #expect(!rules.outerwearRequired(WearWindow(minFeelsLikeC: 12, maxFeelsLikeC: 18, precipProbMax: 59)))
        #expect(rules.outerwearAllowed(WearWindow(minFeelsLikeC: 17, maxFeelsLikeC: 25, precipProbMax: 0), occasion: .casual))
        #expect(!rules.outerwearAllowed(WearWindow(minFeelsLikeC: 20, maxFeelsLikeC: 25, precipProbMax: 0), occasion: .casual))
        #expect(rules.outerwearAllowed(WearWindow(minFeelsLikeC: 20, maxFeelsLikeC: 25, precipProbMax: 0), occasion: .formal))
        let warm = WearWindow(minFeelsLikeC: 18, maxFeelsLikeC: 24, precipProbMax: 0)
        #expect(rules.outerwearForbidden(warm, itemWarmth: .mid))
        #expect(!rules.outerwearForbidden(warm, itemWarmth: .light))
    }

    @Test func otherSlots() {
        #expect(rules.midLayerAllowed(WearWindow(minFeelsLikeC: 21, maxFeelsLikeC: 30, precipProbMax: 0)))
        #expect(!rules.midLayerAllowed(WearWindow(minFeelsLikeC: 22, maxFeelsLikeC: 30, precipProbMax: 0)))
        #expect(rules.heavyForbidden(WearWindow(minFeelsLikeC: 10, maxFeelsLikeC: 15.5, precipProbMax: 0)))
        #expect(rules.lightOnlyForbidden(WearWindow(minFeelsLikeC: 7, maxFeelsLikeC: 12, precipProbMax: 0)))
        #expect(rules.openShoesAllowed(WearWindow(minFeelsLikeC: 15, maxFeelsLikeC: 25, precipProbMax: 39)))
        #expect(!rules.openShoesAllowed(WearWindow(minFeelsLikeC: 15, maxFeelsLikeC: 25, precipProbMax: 40)))
        #expect(rules.isOpenShoe("sandals"))
        #expect(!rules.isOpenShoe("boots"))
    }
}
