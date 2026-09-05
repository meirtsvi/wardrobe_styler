// Vision `ClassifyImageRequest` identifiers → taxonomy (ADR 0001 "What the device classifier can and cannot see").
// Identifiers were read from `ClassifyImageRequest().supportedIdentifiers` on macOS 26.6; LabelMappingTests checks they still exist.
import Domain
import Foundation

public struct CategoryGuess: Equatable, Sendable {
    public var category: Domain.Category
    public var subcategory: String?
    public var confidence: Float
    public var label: String
}

public enum LabelMapping {
    /// identifier → (category, subcategory?)
    public static let table: [String: (Domain.Category, String?)] = [
        "sneaker": (.shoes, "sneakers"), "boot": (.shoes, "boots"), "sandal": (.shoes, "sandals"), "high_heel": (.shoes, "heels"),
        "loafer": (.shoes, "loafers"), "shoes": (.shoes, nil), "footwear": (.shoes, nil),
        "jeans": (.bottom, "jeans"),
        "hoodie": (.top, "hoodie"), "polo": (.top, "polo"),
        "jacket": (.outerwear, nil), "suit": (.outerwear, "blazer"), "lab_coat": (.outerwear, "coat"),
        "wedding_dress": (.onePiece, "dress"), "swimsuit": (.swim, "swimsuit"), "wetsuit": (.swim, "swimsuit"),
        "bag": (.bag, nil), "backpack": (.bag, "backpack"),
        "hat": (.accessory, "hat"), "baseball_hat": (.accessory, "hat"), "cowboy_hat": (.accessory, "hat"), "sunhat": (.accessory, "hat"),
        "scarf": (.accessory, "scarf"), "necktie": (.accessory, "tie"), "bowtie": (.accessory, "tie"), "glove": (.accessory, "gloves"),
        "sock": (.accessory, "socks"), "sunglasses": (.accessory, "sunglasses"), "eyeglasses": (.accessory, "sunglasses"),
        "watch": (.jewelry, "watch"),
    ]

    /// Labels that only say "this is clothing" without a category; they raise the garment prior but never settle the category.
    public static let genericClothing: Set<String> = ["clothing", "clothesline", "iron_clothing"]

    /// Confidence at which the device settles the category without a Gemini attribute call (PLAN §4.3 auto-commit uses ≥ 0.8).
    public static let settleThreshold: Float = 0.6

    public static func guess(from observations: [(identifier: String, confidence: Float)]) -> CategoryGuess? {
        var best: CategoryGuess?
        for o in observations {
            guard let (cat, sub) = table[o.identifier] else { continue }
            if best == nil || o.confidence > best!.confidence {
                best = CategoryGuess(category: cat, subcategory: sub, confidence: o.confidence, label: o.identifier)
            }
        }
        return best
    }

    public static func looksLikeGarment(_ observations: [(identifier: String, confidence: Float)]) -> Float {
        observations.filter { table[$0.identifier] != nil || genericClothing.contains($0.identifier) }.map(\.confidence).max() ?? 0
    }
}
