// SwiftData mirror of the item (PLAN §7.5 `items`, ADR 0001: the device copy is canonical).
import Domain
import Foundation
import SwiftData

@Model
final class ItemRecord {
    @Attribute(.unique) var id: String
    var category: String
    var subcategory: String
    var layerRole: String?
    var colorHex: String
    var colorName: String
    var secondaryHex: [String]
    var pattern: String
    var material: String
    var fit: String?
    var warmth: String
    var season: [String]
    var formality: String
    var occasions: [String]
    var caption: String
    var status: String          // new | auto | confirmed | archived
    var availability: String    // available | laundry | repair | packed | lent
    var owned: Bool
    var quantity: Int
    var isSeed: Bool
    var wearCount: Int
    var lastSuggestedAt: Date?
    var lastWornOn: Date?
    var favorite: Bool
    var source: String          // photo | manual | seed
    var attributesSource: String // device | gemini | user
    var categoryConfidence: Double
    var maskCoverage: Double
    var featurePrint: Data?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    @Attribute(.externalStorage) var cutoutJPEG: Data?
    @Attribute(.externalStorage) var thumbnailJPEG: Data?
    /// Optional Gemini clean-up (PLAN §5.16): a generated image, kept beside the real-pixel cutout and shown only when `useCleaned`.
    @Attribute(.externalStorage) var cleanedJPEG: Data?
    var useCleaned: Bool = false

    var displayCutout: Data? { useCleaned ? (cleanedJPEG ?? cutoutJPEG) : cutoutJPEG }
    var displayThumbnail: Data? { useCleaned ? (cleanedJPEG ?? thumbnailJPEG) : thumbnailJPEG }

    init(id: String = UUID().uuidString, category: Domain.Category, subcategory: String, colorHex: String, colorName: String) {
        self.id = id
        self.category = category.rawValue
        self.subcategory = subcategory
        self.layerRole = Taxonomy.shared.defaultLayerRole(category: category, subcategory: subcategory)?.rawValue
        self.colorHex = colorHex
        self.colorName = colorName
        self.secondaryHex = []
        self.pattern = "solid"
        self.material = "unknown"
        self.warmth = "mid"
        self.season = []
        self.formality = "casual"
        self.occasions = []
        self.caption = ""
        self.status = "new"
        self.availability = "available"
        self.owned = true
        self.quantity = 1
        self.isSeed = false
        self.wearCount = 0
        self.favorite = false
        self.source = "photo"
        self.attributesSource = "device"
        self.categoryConfidence = 0
        self.maskCoverage = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var domainItem: WardrobeItem {
        WardrobeItem(
            id: id,
            category: Domain.Category(rawValue: category) ?? .other,
            subcategory: subcategory,
            layerRole: layerRole.flatMap(LayerRole.init(rawValue:)),
            colorHex: colorHex, colorName: colorName, pattern: pattern, material: material, fit: fit,
            warmth: Warmth(rawValue: warmth) ?? .mid,
            season: season.compactMap(Season.init(rawValue:)),
            formality: Formality(rawValue: formality) ?? .casual,
            owned: owned,
            status: ItemStatus(rawValue: status) ?? .new,
            availability: AvailabilityState(rawValue: availability) ?? .available,
            quantity: quantity, isSeed: isSeed, wearCount: wearCount, lastSuggestedAt: lastSuggestedAt, deleted: deletedAt != nil)
    }

    var displayName: String { "\(colorName.replacingOccurrences(of: "_", with: " ")) \(subcategory.replacingOccurrences(of: "_", with: " "))" }
}

@Model
final class WornEvent {
    var itemId: String
    var outfitKey: String
    var date: Date
    var toLaundry: Bool
    init(itemId: String, outfitKey: String, date: Date = Date(), toLaundry: Bool = false) {
        self.itemId = itemId; self.outfitKey = outfitKey; self.date = date; self.toLaundry = toLaundry
    }
}
