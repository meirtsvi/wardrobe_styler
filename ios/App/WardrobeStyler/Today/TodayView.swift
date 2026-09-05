// Today card (PLAN §4.5): occasion + wear window → on-device plan → validated outfit with rationale and per-slot reasons.
import Domain
import OnDeviceAI
import SwiftData
import SwiftUI
import UIKit

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls
                    if let outcome, !outcome.outfits.isEmpty {
                        OutfitCard(result: outcome.outfits[min(shown, outcome.outfits.count - 1)], records: records, weather: weather.window)
                        HStack {
                            Button("Another look") { shown = (shown + 1) % max(1, outcome.outfits.count); if outcome.outfits.count == 1 { Task { await plan() } } }
                            Spacer()
                            Button { lookFor = outcome.outfits[min(shown, outcome.outfits.count - 1)].outfit } label: { Label("See it on me", systemImage: "person.crop.rectangle") }
                            Spacer()
                            Text(plannerLabel(outcome)).font(.caption).foregroundStyle(.secondary)
                        }
                    } else if outcome != nil {
                        ContentUnavailableView("Nothing works today", systemImage: "cloud.rain", description: Text("Add shoes and a top or a dress that suit \(occasion.rawValue), or mark items as back from the laundry."))
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

    private func plan() async {
        planning = true
        defer { planning = false }
        let items = records.map(\.domainItem)
        let ctx = PlanContext(occasion: occasion, wearWindow: weather.window, accessoryCount: accessories, recentOutfits: RecentOutfits.load(), yesterdayItemIds: RecentOutfits.yesterday())
        outcome = await app.orchestrator.plan(items: items, context: ctx, inputs: StageAInputs(), n: 3, city: weather.city)
        shown = 0
        if let first = outcome?.outfits.first {
            RecentOutfits.record(first.outfit.slots.map(\.itemId))
            let ids = Set(first.outfit.slots.map(\.itemId))
            for r in records where ids.contains(r.id) { r.lastSuggestedAt = Date() }
        }
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
                    if let rec = records.first(where: { $0.id == slot.itemId }), let data = rec.thumbnailJPEG, let ui = UIImage(data: data) {
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
