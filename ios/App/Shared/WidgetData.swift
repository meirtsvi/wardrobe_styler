// Shared between the app and the widget extension (PLAN §6 "Widgets": App Group cache written by the app).
import Foundation

struct TodayWidgetData: Codable, Equatable {
    struct Slot: Codable, Equatable {
        var slot: String
        var name: String
        var thumbnailFile: String? // file name inside the App Group's widget/ directory
    }
    var date: Date
    var occasion: String
    var weatherLine: String // "9° → 21° · rain 10%"
    var rationale: String
    var layeringNote: String?
    var slots: [Slot]
}

enum WidgetStore {
    static let appGroup = "group.com.meirtsvi.wardrobestyler"
    static let kind = "TodayOutfitWidget"

    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    /// App Group directory, or the app's own Application Support when the group entitlement is missing (unsigned builds); the widget then shows the placeholder.
    static var directory: URL? {
        let base = container ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base else { return nil }
        let dir = base.appendingPathComponent("widget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func load() -> TodayWidgetData? {
        guard let dir = directory, let data = try? Data(contentsOf: dir.appendingPathComponent("today.json")) else { return nil }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(TodayWidgetData.self, from: data)
    }

    /// Writes today.json and the thumbnails (already-encoded JPEG bytes keyed by file name), replacing whatever was there.
    static func save(_ today: TodayWidgetData, thumbnails: [String: Data]) throws {
        guard let dir = directory else { throw NSError(domain: "widget", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group container unavailable"]) }
        for f in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] where f.hasSuffix(".jpg") {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
        }
        for (name, bytes) in thumbnails { try bytes.write(to: dir.appendingPathComponent(name)) }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try enc.encode(today).write(to: dir.appendingPathComponent("today.json"), options: .atomic)
    }

    static func thumbnailURL(_ file: String) -> URL? { directory?.appendingPathComponent(file) }
}
