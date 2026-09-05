// Executes shared/rules/temperature.json (PLAN §5.6). Client mirror of backend/src/domain/temperature.ts.
import Foundation

public struct WearWindow: Codable, Equatable, Sendable {
    public var minFeelsLikeC: Double
    public var maxFeelsLikeC: Double
    public var precipProbMax: Double // percent 0–100
    public var windMax: Double?

    public init(minFeelsLikeC: Double, maxFeelsLikeC: Double, precipProbMax: Double, windMax: Double? = nil) {
        self.minFeelsLikeC = minFeelsLikeC
        self.maxFeelsLikeC = maxFeelsLikeC
        self.precipProbMax = precipProbMax
        self.windMax = windMax
    }

    enum CodingKeys: String, CodingKey {
        case minFeelsLikeC = "min_feels_like_c", maxFeelsLikeC = "max_feels_like_c", precipProbMax = "precip_prob_max", windMax = "wind_max"
    }
}

public struct TemperatureRules: Decodable, Sendable {
    public struct Band: Decodable, Sendable {
        public let name: String
        public let minC: Double?
        public let maxC: Double?
        enum CodingKeys: String, CodingKey { case name, minC = "min_c", maxC = "max_c" }
    }
    struct OrPrecip: Decodable, Sendable {
        let precipProbMaxGtePct: Double
        let minFeelsLikeLtC: Double
        enum CodingKeys: String, CodingKey { case precipProbMaxGtePct = "precip_prob_max_gte_pct", minFeelsLikeLtC = "min_feels_like_lt_c" }
    }
    struct Rule: Decodable, Sendable {
        let text: String
        let minFeelsLikeLtC: Double?
        let minFeelsLikeGteC: Double?
        let maxFeelsLikeGteC: Double?
        let maxFeelsLikeGtC: Double?
        let precipProbMaxLtPct: Double?
        let orPrecip: OrPrecip?
        let orOccasionIn: [String]?
        let unlessItemWarmth: String?
        let subcategories: [String]?
        enum CodingKeys: String, CodingKey {
            case text, subcategories
            case minFeelsLikeLtC = "min_feels_like_lt_c", minFeelsLikeGteC = "min_feels_like_gte_c"
            case maxFeelsLikeGteC = "max_feels_like_gte_c", maxFeelsLikeGtC = "max_feels_like_gt_c"
            case precipProbMaxLtPct = "precip_prob_max_lt_pct", orPrecip = "or_precip", orOccasionIn = "or_occasion_in"
            case unlessItemWarmth = "unless_item_warmth"
        }
    }

    public let version: Int
    public let bands: [Band]
    let rules: [String: Rule]

    public static let shared: TemperatureRules = SharedResources.decode("temperature")

    func rule(_ id: String) -> Rule {
        guard let r = rules[id] else { fatalError("temperature.json is missing rule \(id)") }
        return r
    }

    public func band(_ feelsLikeC: Double) -> String {
        for b in bands {
            let min = b.minC ?? -.infinity
            let max = b.maxC ?? .infinity
            if feelsLikeC >= min && feelsLikeC < max { return b.name }
        }
        return bands.last?.name ?? "hot"
    }

    public func spansTwoBands(_ w: WearWindow) -> Bool { band(w.minFeelsLikeC) != band(w.maxFeelsLikeC) }

    public func outerwearRequired(_ w: WearWindow) -> Bool {
        let r = rule("outerwear_required")
        if w.minFeelsLikeC < r.minFeelsLikeLtC! { return true }
        if let p = r.orPrecip, w.precipProbMax >= p.precipProbMaxGtePct, w.minFeelsLikeC < p.minFeelsLikeLtC { return true }
        return false
    }

    public func outerwearAllowed(_ w: WearWindow, occasion: Occasion) -> Bool {
        let r = rule("outerwear_allowed")
        return outerwearRequired(w) || w.minFeelsLikeC < r.minFeelsLikeLtC! || (r.orOccasionIn ?? []).contains(occasion.rawValue)
    }

    public func outerwearForbidden(_ w: WearWindow, itemWarmth: Warmth) -> Bool {
        let r = rule("outerwear_forbidden")
        return w.maxFeelsLikeC >= r.maxFeelsLikeGteC! && itemWarmth.rawValue != r.unlessItemWarmth
    }

    public func midLayerAllowed(_ w: WearWindow) -> Bool { w.minFeelsLikeC < rule("mid_layer_allowed").minFeelsLikeLtC! }
    public func baseLayerAllowedByTemperature(_ w: WearWindow) -> Bool { w.minFeelsLikeC < rule("base_layer_allowed_by_temperature").minFeelsLikeLtC! }
    public func heavyForbidden(_ w: WearWindow) -> Bool { w.maxFeelsLikeC > rule("heavy_warmth_forbidden").maxFeelsLikeGtC! }
    public func lightOnlyForbidden(_ w: WearWindow) -> Bool { w.minFeelsLikeC < rule("light_only_forbidden").minFeelsLikeLtC! }
    public func isOpenShoe(_ subcategory: String) -> Bool { (rule("open_shoes_allowed").subcategories ?? []).contains(subcategory) }

    public func openShoesAllowed(_ w: WearWindow) -> Bool {
        let r = rule("open_shoes_allowed")
        return w.minFeelsLikeC >= r.minFeelsLikeGteC! && w.precipProbMax < r.precipProbMaxLtPct!
    }
}

public extension TemperatureRules {
    /// The rule table as prose for the on-device Stage B instructions, so prompt and validator share one source (mirrors renderTemperatureRulesText()).
    var renderedText: String {
        let bandText = bands.map { b -> String in
            if b.minC == nil, let max = b.maxC { return "\(b.name) below \(Int(max)) °C" }
            if b.maxC == nil, let min = b.minC { return "\(b.name) above \(Int(min)) °C" }
            return "\(b.name) \(Int(b.minC ?? 0))–\(Int(b.maxC ?? 0)) °C"
        }.joined(separator: ", ")
        let lines = rules.keys.sorted().map { "- \(rules[$0]!.text) [\($0)]" }
        return ([
            "Temperature bands (feels-like): \(bandText).",
            "Layering rules (evaluate required/allowed against the minimum feels-like of the wear window and forbidden against the maximum):",
        ] + lines + ["When the wear window spans two bands, say how the layers come off during the day in layering_note."]).joined(separator: "\n")
    }
}
