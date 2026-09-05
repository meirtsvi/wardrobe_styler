import Testing
@testable import Domain

@Suite struct TaxonomyTests {
    let t = Taxonomy.shared

    @Test func enumsMatchSharedJSON() {
        #expect(Category.allCases.map(\.rawValue) == t.categories)
        #expect(Slot.allCases.map(\.rawValue) == t.slots)
        #expect(LayerRole.allCases.map(\.rawValue) == t.layerRoles)
        #expect(Warmth.allCases.map(\.rawValue) == t.warmth)
        #expect(Formality.allCases.map(\.rawValue) == t.formality)
        #expect(Season.allCases.map(\.rawValue) == t.seasons)
        #expect(Occasion.allCases.map(\.rawValue) == t.occasions)
        #expect(Set(AccessoryCount.allCases.map(\.rawValue)) == Set(t.accessoryCount.keys))
        #expect(ItemStatus.allCases.map(\.rawValue) == t.itemStatus)
        #expect(AvailabilityState.allCases.map(\.rawValue) == t.availabilityState)
    }

    @Test func formalityPerOccasion() {
        #expect(t.formalityAllowed(.business, for: .work))
        #expect(t.formalityAllowed(.smartCasual, for: .work))
        #expect(t.formalityAllowed(.formal, for: .work))
        #expect(!t.formalityAllowed(.casual, for: .work))
        #expect(!t.formalityAllowed(.athletic, for: .work))
        #expect(t.formalityAllowed(.athletic, for: .sport))
        #expect(!t.formalityAllowed(.casual, for: .sport))
    }

    @Test func layerRoleDefaults() {
        #expect(t.defaultLayerRole(category: .top, subcategory: "tank") == .base)
        #expect(t.defaultLayerRole(category: .top, subcategory: "shirt") == .single)
        #expect(t.defaultLayerRole(category: .midLayer, subcategory: "cardigan") == .mid)
        #expect(t.defaultLayerRole(category: .bottom, subcategory: "jeans") == nil)
        #expect(t.maxItems(in: .jewelry) == 3 && t.maxItems(in: .top) == 1)
    }
}
