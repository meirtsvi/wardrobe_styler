// Week planner strip (PLAN §4.5, §4.11 "week strip"): seven rule-based plans with rotation across the week; tap a day to see it.
import Domain
import OnDeviceAI
import SwiftUI
import UIKit

struct DayPlan: Identifiable {
    let date: Date
    let window: WearWindow
    let outfit: PlannedOutfit?
    var id: Date { date }
}

@MainActor
enum WeekPlanner {
    /// Plans the next 7 days with the combiner (instant, offline). Each day's items are added to the no-repeat list for the following days.
    static func plan(items: [WardrobeItem], occasion: Occasion, windows: [WearWindow], accessories: AccessoryCount, recent: [[String]]) -> [DayPlan] {
        let stageA = StageA(), combiner = Combiner()
        var history = recent
        var out: [DayPlan] = []
        var day = Calendar.current.startOfDay(for: Date())
        for i in 0..<7 {
            let w = windows.indices.contains(i) ? windows[i] : (windows.last ?? WearWindow(minFeelsLikeC: 16, maxFeelsLikeC: 22, precipProbMax: 10))
            let ctx = PlanContext(occasion: occasion, wearWindow: w, accessoryCount: accessories, recentOutfits: history, yesterdayItemIds: out.last?.outfit?.slots.map(\.itemId) ?? [])
            let inputs = StageAInputs(today: day)
            let cands = stageA.run(items, ctx: ctx, inputs: inputs)
            let outfit = combiner.combine(cands, ctx: ctx)
            if let outfit { history.append(outfit.slots.map(\.itemId)) }
            out.append(DayPlan(date: day, window: w, outfit: outfit))
            day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return out
    }
}

struct WeekStrip: View {
    let days: [DayPlan]
    let records: [ItemRecord]
    @Binding var selected: DayPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week").font(.subheadline).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(days) { d in
                        Button { selected = d } label: {
                            VStack(spacing: 6) {
                                Text(d.date.formatted(.dateTime.weekday(.abbreviated))).font(.caption).bold()
                                Text("\(Int(d.window.minFeelsLikeC.rounded()))–\(Int(d.window.maxFeelsLikeC.rounded()))°").font(.caption2).foregroundStyle(.secondary)
                                if let o = d.outfit {
                                    HStack(spacing: -10) {
                                        ForEach(Array(o.slots.prefix(3)), id: \.itemId) { s in
                                            if let r = records.first(where: { $0.id == s.itemId }), let data = r.displayThumbnail, let ui = UIImage(data: data) {
                                                Image(uiImage: ui).resizable().scaledToFill().frame(width: 34, height: 34).clipShape(Circle()).overlay(Circle().stroke(.background, lineWidth: 2))
                                            }
                                        }
                                    }
                                } else {
                                    Image(systemName: "questionmark.circle").foregroundStyle(.secondary).frame(height: 34)
                                }
                            }
                            .padding(8)
                            .frame(width: 92)
                            .background(selected?.id == d.id ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
