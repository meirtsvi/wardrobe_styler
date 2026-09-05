// One ingest path for PhotosPicker and the debug `--ingest-file` hook: Vision digitise → SwiftData record → Gemini naming when the device cannot settle it.
import Digitize
import Domain
import Foundation
import OnDeviceAI
import SwiftData
import UIKit

@MainActor
struct Ingestor {
    let app: AppModel
    let context: ModelContext

    /// Returns the number of garments stored from one photo. Throws on decode/Vision failure.
    @discardableResult
    func ingest(_ image: UIImage) async throws -> Int {
        guard let cg = ImagePrep.normalised(image, longEdge: 1536) else { return 0 }
        let garments = try await app.digitizer.digitize(cg)
        var stored = 0
        for g in garments where g.garmentScore > 0.1 || g.categoryGuess != nil || garments.count == 1 {
            let primary = g.palette.first
            let record = ItemRecord(category: g.categoryGuess?.category ?? .other,
                                    subcategory: g.categoryGuess?.subcategory ?? (g.categoryGuess?.category.rawValue ?? "other"),
                                    colorHex: primary?.hex ?? "#8C8C8C", colorName: primary?.name ?? "grey")
            record.secondaryHex = g.palette.dropFirst().map(\.hex)
            record.categoryConfidence = Double(g.categoryGuess?.confidence ?? 0)
            record.maskCoverage = g.maskCoverage
            record.cutoutJPEG = ImagePrep.jpeg(g.cutout, quality: 0.85)
            record.thumbnailJPEG = ImagePrep.jpeg(g.thumbnail, quality: 0.8)
            record.attributesSource = g.needsCloudAttributes ? "device_partial" : "device"
            if g.needsCloudAttributes, let gateway = app.gateway, let cutout = record.cutoutJPEG {
                try await nameWithGemini(record, gateway: gateway, cutout: cutout, label: g.categoryGuess?.label)
            }
            // PLAN §4.3: high-confidence items commit automatically; doubtful ones wait in the review queue.
            record.status = record.categoryConfidence >= 0.8 && record.attributesSource != "device_partial" ? "auto" : "new"
            context.insert(record)
            stored += 1
        }
        try context.save()
        return stored
    }

    /// ADR 0001: Gemini names garments the device classifier cannot; colour stays the measured pixels.
    func nameWithGemini(_ record: ItemRecord, gateway: GatewayClient, cutout: Data, label: String?) async throws {
        let r = try await gateway.attributes(cutout: InlineImage(mimeType: "image/jpeg", data: cutout), primaryHex: record.colorHex, primaryName: record.colorName,
                                             secondaryHex: record.secondaryHex, detectionLabel: label)
        let a = r.attributes
        if let cat = Domain.Category(rawValue: a.category) {
            record.category = cat.rawValue
            let subs = Taxonomy.shared.subcategories[cat.rawValue] ?? []
            record.subcategory = subs.contains(a.subcategory) ? a.subcategory : (subs.first ?? "other")
            record.layerRole = a.layer_role ?? Taxonomy.shared.defaultLayerRole(category: cat, subcategory: record.subcategory)?.rawValue
        }
        record.pattern = a.pattern; record.material = a.material; record.fit = a.fit; record.warmth = a.warmth
        record.season = a.season; record.formality = a.formality; record.occasions = a.occasions; record.caption = a.caption
        record.categoryConfidence = a.field_confidences["category"] ?? 0.7
        record.attributesSource = "gemini"
    }

    /// Debug: `--ingest-file /abs/path.png` (repeatable) runs the full pipeline at launch. The simulator can read host paths.
    static func debugFiles() -> [String] {
        let args = ProcessInfo.processInfo.arguments
        return args.enumerated().filter { $0.element == "--ingest-file" }.compactMap { args.indices.contains($0.offset + 1) ? args[$0.offset + 1] : nil }
    }
}
