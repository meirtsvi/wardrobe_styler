// Debug-only fixture closet (launch argument `--seed-demo`) for simulator smoke tests and screenshots. Not the §11.3 seed catalogue.
import Domain
import Foundation
import SwiftData
import UIKit

enum DemoSeed {
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("--seed-demo") }

    @MainActor
    static func seedIfEmpty(_ context: ModelContext) {
        guard requested, ((try? context.fetchCount(FetchDescriptor<ItemRecord>())) ?? 0) == 0 else { return }
        let rows: [(Domain.Category, String, String, String, Warmth, Formality)] = [
            (.top, "tee", "#F7F7F5", "white", .light, .casual), (.top, "shirt", "#2F5DA8", "blue", .mid, .smartCasual),
            (.top, "sweater", "#8C8C8C", "grey", .warm, .smartCasual), (.bottom, "jeans", "#1F2A44", "navy", .mid, .casual),
            (.bottom, "chinos", "#C8A97E", "tan", .mid, .smartCasual), (.onePiece, "dress", "#111111", "black", .light, .smartCasual),
            (.midLayer, "cardigan", "#9CAF88", "sage", .mid, .smartCasual), (.outerwear, "trench", "#C19A6B", "camel", .light, .smartCasual),
            (.outerwear, "parka", "#111111", "black", .heavy, .casual), (.shoes, "sneakers", "#F7F7F5", "white", .mid, .casual),
            (.shoes, "boots", "#6B4A2B", "brown", .warm, .smartCasual), (.bag, "tote", "#111111", "black", .mid, .smartCasual),
            (.jewelry, "necklace", "#C9A227", "gold", .mid, .smartCasual), (.jewelry, "earrings", "#BFC4C9", "silver", .mid, .smartCasual),
            (.accessory, "belt", "#6B4A2B", "brown", .mid, .smartCasual),
        ]
        for (cat, sub, hex, name, warmth, formality) in rows {
            let r = ItemRecord(category: cat, subcategory: sub, colorHex: hex, colorName: name)
            r.warmth = warmth.rawValue; r.formality = formality.rawValue; r.status = "confirmed"; r.source = "manual"; r.attributesSource = "user"
            r.thumbnailJPEG = swatch(hex: hex, size: 256); r.cutoutJPEG = swatch(hex: hex, size: 512)
            context.insert(r)
        }
        try? context.save()
    }

    private static func swatch(hex: String, size: CGFloat) -> Data? {
        let c = ColorMath.rgb(fromHex: hex) ?? (140, 140, 140)
        let img = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            UIColor(red: c.r / 255, green: c.g / 255, blue: c.b / 255, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: size * 0.2, y: size * 0.15, width: size * 0.6, height: size * 0.7), cornerRadius: size * 0.1).fill()
        }
        return img.jpegData(compressionQuality: 0.8)
    }
}
