// Export ZIP (PLAN §4.14 "your data", v1.1 export): cutouts + items.json + wear_log.csv, zipped with NSFileCoordinator, handed to the share sheet.
import Foundation
import SwiftUI
import UIKit

enum Export {
    struct ItemJSON: Codable {
        var id: String, category: String, subcategory: String, layer_role: String?, color_hex: String, color_name: String, pattern: String, material: String
        var warmth: String, season: [String], formality: String, status: String, availability: String, quantity: Int, wear_count: Int
        var last_worn_on: String?, created_at: String, caption: String, named_by: String, cutout_file: String?
    }

    /// Builds `WardrobeExport-<date>.zip` in the temporary directory and returns its URL.
    static func build(items: [ItemRecord], events: [WornEvent]) throws -> URL {
        let fm = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let root = fm.temporaryDirectory.appendingPathComponent("WardrobeExport-\(stamp)", isDirectory: true)
        let cutouts = root.appendingPathComponent("cutouts", isDirectory: true)
        try? fm.removeItem(at: root)
        try fm.createDirectory(at: cutouts, withIntermediateDirectories: true)

        let iso = ISO8601DateFormatter()
        var rows: [ItemJSON] = []
        for it in items {
            var file: String? = nil
            if let data = it.cutoutJPEG {
                file = "cutouts/\(it.id).jpg"
                try data.write(to: root.appendingPathComponent(file!))
            }
            rows.append(ItemJSON(id: it.id, category: it.category, subcategory: it.subcategory, layer_role: it.layerRole, color_hex: it.colorHex, color_name: it.colorName,
                                 pattern: it.pattern, material: it.material, warmth: it.warmth, season: it.season, formality: it.formality, status: it.status,
                                 availability: it.availability, quantity: it.quantity, wear_count: it.wearCount, last_worn_on: it.lastWornOn.map(iso.string),
                                 created_at: iso.string(from: it.createdAt), caption: it.caption, named_by: it.attributesSource, cutout_file: file))
        }
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(rows).write(to: root.appendingPathComponent("items.json"))

        var csv = "date,item_id,outfit,to_laundry\n"
        for e in events.sorted(by: { $0.date < $1.date }) { csv += "\(iso.string(from: e.date)),\(e.itemId),\"\(e.outfitKey)\",\(e.toLaundry)\n" }
        try csv.write(to: root.appendingPathComponent("wear_log.csv"), atomically: true, encoding: .utf8)
        try "Exported from Wardrobe Styler on \(Date().formatted()). items.json lists every item; cutouts/ holds the real-pixel cutouts; wear_log.csv is the wear history.\n"
            .write(to: root.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)

        // NSFileCoordinator's .forUploading option produces a zip archive of a directory without any extra library.
        var zipURL: URL?
        var copyError: Error?
        var coordError: NSError?
        let dest = fm.temporaryDirectory.appendingPathComponent("WardrobeExport-\(stamp).zip")
        try? fm.removeItem(at: dest)
        NSFileCoordinator().coordinate(readingItemAt: root, options: .forUploading, error: &coordError) { tmp in
            do { try fm.copyItem(at: tmp, to: dest); zipURL = dest } catch { copyError = error }
        }
        if let coordError { throw coordError }
        if let copyError { throw copyError }
        guard let zipURL else { throw NSError(domain: "export", code: 1, userInfo: [NSLocalizedDescriptionKey: "zip failed"]) }
        try? fm.removeItem(at: root)
        return zipURL
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
