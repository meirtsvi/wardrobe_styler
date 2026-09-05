// shared/rules/color_palette.json (PLAN §5.4, §5.6).
import Foundation

public struct ColorPalette: Decodable, Sendable {
    public struct Harmony: Decodable, Sendable {
        public struct Scores: Decodable, Sendable {
            public let monochrome: Double, analogous: Double, neutral: Double, complementary: Double, other: Double
        }
        public let neutralChromaMax: Double
        public let monochromeHueDeg: Double
        public let analogousHueDeg: Double
        public let complementaryMinDeg: Double
        public let complementaryMaxDeg: Double
        public let scores: Scores
        enum CodingKeys: String, CodingKey {
            case scores
            case neutralChromaMax = "neutral_chroma_max", monochromeHueDeg = "monochrome_hue_deg", analogousHueDeg = "analogous_hue_deg"
            case complementaryMinDeg = "complementary_min_deg", complementaryMaxDeg = "complementary_max_deg"
        }
    }

    public let version: Int
    public let named: [String: String]
    public let neutrals: [String]
    public let seasonal: [String: [String]]
    public let harmony: Harmony

    public static let shared: ColorPalette = SharedResources.decode("color_palette")

    public func seasonal(_ season: Season) -> [String] { seasonal[season.rawValue] ?? [] }
}
