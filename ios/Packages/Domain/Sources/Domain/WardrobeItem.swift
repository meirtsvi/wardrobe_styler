// The on-device wardrobe item as the planner sees it (ADR 0001: SwiftData is canonical; this is the value type mapped from the @Model).
import Foundation

public struct WardrobeItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var category: Category
    public var subcategory: String
    public var layerRole: LayerRole?
    public var colorHex: String
    public var colorName: String
    public var pattern: String
    public var material: String
    public var fit: String?
    public var warmth: Warmth
    public var season: [Season]
    public var formality: Formality
    public var owned: Bool
    public var status: ItemStatus
    public var availability: AvailabilityState
    public var quantity: Int
    public var isSeed: Bool
    public var wearCount: Int
    public var lastSuggestedAt: Date?
    public var deleted: Bool

    public init(id: String, category: Category, subcategory: String, layerRole: LayerRole? = nil, colorHex: String = "#1F2A44", colorName: String = "navy",
                pattern: String = "solid", material: String = "cotton", fit: String? = nil, warmth: Warmth = .mid, season: [Season] = [],
                formality: Formality = .smartCasual, owned: Bool = true, status: ItemStatus = .confirmed, availability: AvailabilityState = .available,
                quantity: Int = 1, isSeed: Bool = false, wearCount: Int = 0, lastSuggestedAt: Date? = nil, deleted: Bool = false) {
        self.id = id; self.category = category; self.subcategory = subcategory
        self.layerRole = layerRole ?? Taxonomy.shared.defaultLayerRole(category: category, subcategory: subcategory)
        self.colorHex = colorHex; self.colorName = colorName; self.pattern = pattern; self.material = material; self.fit = fit
        self.warmth = warmth; self.season = season; self.formality = formality; self.owned = owned; self.status = status
        self.availability = availability; self.quantity = quantity; self.isSeed = isSeed; self.wearCount = wearCount
        self.lastSuggestedAt = lastSuggestedAt; self.deleted = deleted
    }
}

public struct ItemFeedback: Equatable, Sendable {
    public var thumbsUp: Int
    public var thumbsDownInOccasion: Int
    public var starsAbove3: Int
    public var disliked: Bool
    public init(thumbsUp: Int = 0, thumbsDownInOccasion: Int = 0, starsAbove3: Int = 0, disliked: Bool = false) {
        self.thumbsUp = thumbsUp; self.thumbsDownInOccasion = thumbsDownInOccasion; self.starsAbove3 = starsAbove3; self.disliked = disliked
    }
}

public struct ColorSeason: Codable, Equatable, Sendable {
    public var bestHex: [String]
    public var avoidHex: [String]
    public init(bestHex: [String], avoidHex: [String]) { self.bestHex = bestHex; self.avoidHex = avoidHex }
}

/// Everything Stage A needs beyond PlanContext (PLAN §5.6 score terms).
public struct StageAInputs: Sendable {
    public var today: Date
    public var calendarSeason: Season
    public var bodyAvoid: [String]
    public var colorSeason: ColorSeason?
    public var feedback: [String: ItemFeedback]
    /// subcategory → days since another item of it was suggested
    public var recentSubcategorySuggestions: [String: Int]

    public init(today: Date = Date(), calendarSeason: Season? = nil, bodyAvoid: [String] = [], colorSeason: ColorSeason? = nil,
                feedback: [String: ItemFeedback] = [:], recentSubcategorySuggestions: [String: Int] = [:]) {
        self.today = today
        self.calendarSeason = calendarSeason ?? Self.season(for: today)
        self.bodyAvoid = bodyAvoid; self.colorSeason = colorSeason; self.feedback = feedback
        self.recentSubcategorySuggestions = recentSubcategorySuggestions
    }

    /// Northern-hemisphere meteorological seasons; the app flips this for southern users from the profile.
    public static func season(for date: Date, calendar: Calendar = .current) -> Season {
        switch calendar.component(.month, from: date) {
        case 12, 1, 2: return .winter
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        default: return .autumn
        }
    }
}
