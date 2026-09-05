// Wear log (PLAN §4.5 "wear this" / "→ laundry", §7.5 wear_events): item-level events feed rotation and cost-per-wear later.
import Domain
import Foundation
import SwiftData

enum WearLog {
    /// Records today's wear of every item in the outfit; optionally sends the clothing to the laundry.
    @MainActor
    static func wear(_ outfit: PlannedOutfit, records: [ItemRecord], toLaundry: Bool, context: ModelContext, date: Date = Date()) {
        let key = outfit.slots.map(\.itemId).joined(separator: "+")
        let laundrySlots: Set<Slot> = [.onePiece, .top, .baseLayer, .midLayer, .bottom]
        for slot in outfit.slots {
            guard let rec = records.first(where: { $0.id == slot.itemId }) else { continue }
            context.insert(WornEvent(itemId: rec.id, outfitKey: key, date: date, toLaundry: toLaundry && laundrySlots.contains(slot.slot)))
            rec.wearCount += 1
            rec.lastWornOn = date
            if toLaundry && laundrySlots.contains(slot.slot) { rec.availability = "laundry" }
        }
        try? context.save()
    }

    /// Events grouped by day, newest first, for the Me tab history.
    static func grouped(_ events: [WornEvent], calendar: Calendar = .current) -> [(day: Date, events: [WornEvent])] {
        let groups = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.date > $1.date }) }
    }
}
