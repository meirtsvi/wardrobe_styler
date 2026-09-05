// Today card (PLAN §4.5): occasion + wear window → on-device plan → validated outfit with rationale and per-slot reasons.
import Domain
import OnDeviceAI
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Query(filter: #Predicate<ItemRecord> { $0.deletedAt == nil }) private var records: [ItemRecord]
    @State private var occasion: Occasion = .casual
    @State private var weather = WeatherState()
    @State private var accessories: AccessoryCount = .some
    @State private var outcome: PlanOutcome?
    @State private var shown = 0
    @State private var planning = false
    @State private var lookFor: PlannedOutfit?
    @State private var week: [DayPlan] = []
    @State private var selectedDay: DayPlan?
    @State private var wornMessage: String?
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls
                    if let outcome, !outcome.outfits.isEmpty {
                        let current = outcome.outfits[min(shown, outcome.outfits.count - 1)]
                        OutfitCard(result: current, records: records, weather: weather.window)
                        HStack {
                            Button("Another look") { shown = (shown + 1) % max(1, outcome.outfits.count); if outcome.outfits.count == 1 { Task { await plan() } } }
                            Spacer()
                            Button { lookFor = current.outfit } label: { Label("See it on me", systemImage: "person.crop.rectangle") }
                            Spacer()
                            Text(plannerLabel(outcome)).font(.caption).foregroundStyle(.secondary)
                        }
                        HStack {
                            Button { wear(current.outfit, laundry: false) } label: { Label("Wear this", systemImage: "checkmark.circle") }.buttonStyle(.bordered)
                            Button { wear(current.outfit, laundry: true) } label: { Label("Wear → laundry", systemImage: "washer") }.buttonStyle(.bordered)
                            Spacer()
                        }
                        if let wornMessage { Text(wornMessage).font(.caption).foregroundStyle(.secondary) }
                    } else if outcome != nil {
                        ContentUnavailableView("Nothing works today", systemImage: "cloud.rain", description: Text("Add shoes and a top or a dress that suit \(occasion.rawValue), or mark items as back from the laundry."))
                    }
                    if !week.isEmpty {
                        WeekStrip(days: week, records: records, selected: $selectedDay)
                        if let d = selectedDay, let o = d.outfit {
                            Text(d.date.formatted(date: .complete, time: .omitted)).font(.subheadline).bold()
                            OutfitCard(result: PlannedResult(outfit: o, passed: true, rulesFailed: [], repaired: false, fallback: true, plannerName: "combiner", advisoryWarnings: []), records: records, weather: d.window)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .sheet(item: $lookFor) { o in LookSheet(outfit: o, records: records) }
            .task { if outcome == nil, !records.isEmpty { await plan() } }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Occasion", selection: $occasion) {
                ForEach([Occasion.casual, .work, .date, .event, .travel, .sport], id: \.rawValue) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            WeatherControls(state: $weather)
            Picker("Accessories", selection: $accessories) { ForEach(AccessoryCount.allCases, id: \.rawValue) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            Button { Task { await plan() } } label: {
                Label(planning ? "Planning…" : "Dress me", systemImage: "sparkles").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).disabled(planning || records.isEmpty)
        }
    }

    private func plannerLabel(_ o: PlanOutcome) -> String {
        let r = o.outfits.first
        if r?.fallback == true { return "rule-based" }
        return (r?.plannerName ?? "") + (r?.repaired == true ? " · repaired" : "")
    }

    private func wear(_ outfit: PlannedOutfit, laundry: Bool) {
        WearLog.wear(outfit, records: records, toLaundry: laundry, context: context)
        wornMessage = laundry ? "Logged and sent the clothes to the laundry." : "Logged as worn today."
        planWeek()
    }

    private func planWeek() {
        let items = records.map(\.domainItem)
        week = WeekPlanner.plan(items: items, occasion: occasion, windows: weather.weekWindows.isEmpty ? [weather.window] : weather.weekWindows, accessories: accessories, recent: RecentOutfits.load())
        if let sel = selectedDay { selectedDay = week.first { $0.id == sel.id } }
    }

    private func plan() async {
        planning = true
        defer { planning = false }
        planWeek()
        let items = records.map(\.domainItem)
        let ctx = PlanContext(occasion: occasion, wearWindow: weather.window, accessoryCount: accessories, recentOutfits: RecentOutfits.load(), yesterdayItemIds: RecentOutfits.yesterday())
        outcome = await app.orchestrator.plan(items: items, context: ctx, inputs: StageAInputs(), n: 3, city: weather.city)
        shown = 0
        if let first = outcome?.outfits.first {
            RecentOutfits.record(first.outfit.slots.map(\.itemId))
            let ids = Set(first.outfit.slots.map(\.itemId))
            for r in records where ids.contains(r.id) { r.lastSuggestedAt = Date() }
            publishWidget(first.outfit)
        }
    }

    /// PLAN §6 "Widgets": the app writes the App Group cache and reloads the timeline; the widget never plans on its own.
    private func publishWidget(_ outfit: PlannedOutfit) {
        var thumbs: [String: Data] = [:]
        let slots = outfit.slots.map { s -> TodayWidgetData.Slot in
            let rec = records.first { $0.id == s.itemId }
            var file: String? = nil
            if let rec, let data = rec.displayThumbnail { file = "\(rec.id).jpg"; thumbs[file!] = data }
            return TodayWidgetData.Slot(slot: s.slot.rawValue, name: rec?.displayName ?? s.itemId, thumbnailFile: file)
        }
        let w = weather.window
        let data = TodayWidgetData(date: Date(), occasion: occasion.rawValue,
                                   weatherLine: "\(Int(w.minFeelsLikeC.rounded()))° → \(Int(w.maxFeelsLikeC.rounded()))° · rain \(Int(w.precipProbMax))%",
                                   rationale: outfit.rationale, layeringNote: outfit.layeringNote, slots: slots)
        do { try WidgetStore.save(data, thumbnails: thumbs); WidgetCenter.shared.reloadTimelines(ofKind: WidgetStore.kind) } catch { print("[widget] \(error)") }
    }
}

struct OutfitCard: View {
    let result: PlannedResult
    let records: [ItemRecord]
    let weather: WearWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(Int(weather.minFeelsLikeC.rounded()))° → \(Int(weather.maxFeelsLikeC.rounded()))°  ·  rain \(Int(weather.precipProbMax))%")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(result.outfit.rationale).font(.headline)
            if let note = result.outfit.layeringNote { Text(note).font(.subheadline) }
            ForEach(result.outfit.slots, id: \.itemId) { slot in
                HStack(spacing: 12) {
                    if let rec = records.first(where: { $0.id == slot.itemId }), let data = rec.displayThumbnail, let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFit().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(.quaternary).frame(width: 56, height: 56)
                    }
                    VStack(alignment: .leading) {
                        Text(records.first(where: { $0.id == slot.itemId })?.displayName ?? slot.itemId).font(.body)
                        Text(slot.reason).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(slot.slot.rawValue.replacingOccurrences(of: "_", with: " ")).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            if !result.advisoryWarnings.isEmpty { Text(result.advisoryWarnings.joined(separator: ", ")).font(.caption2).foregroundStyle(.orange) }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Persists the last 14 days of shown outfits for the no-repeat rule (PLAN §5.6). Local only.
enum RecentOutfits {
    private static let key = "recent.outfits.v1"
    struct Entry: Codable { var ids: [String]; var at: Date }
    static func load() -> [[String]] { entries().map(\.ids) }
    static func yesterday() -> [String] {
        let cal = Calendar.current
        return entries().filter { cal.isDateInYesterday($0.at) }.flatMap(\.ids)
    }
    static func record(_ ids: [String]) {
        var all = entries()
        all.append(Entry(ids: ids, at: Date()))
        if let data = try? JSONEncoder().encode(all) { UserDefaults.standard.set(data, forKey: key) }
    }
    private static func entries() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key), let all = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        let cutoff = Date().addingTimeInterval(-14 * 86_400)
        return all.filter { $0.at > cutoff }
    }
}

extension PlannedOutfit: @retroactive Identifiable {
    public var id: String { slots.map(\.itemId).joined(separator: "+") }
}
