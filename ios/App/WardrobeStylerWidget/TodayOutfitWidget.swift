// Home-screen widget (PLAN §4.5 "widget", §6 "Widgets"): today's outfit from the App Group cache; tapping opens the Today tab.
import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let data: TodayWidgetData?
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), data: TodayWidgetData(date: Date(), occasion: "casual", weatherLine: "16° → 22° · rain 10%", rationale: "Analogous blues for a mild day.", layeringNote: nil,
                                                       slots: [.init(slot: "top", name: "blue shirt", thumbnailFile: nil), .init(slot: "bottom", name: "navy jeans", thumbnailFile: nil), .init(slot: "shoes", name: "white sneakers", thumbnailFile: nil)]))
    }
    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), data: WidgetStore.load() ?? placeholder(in: context).data))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: Date(), data: WidgetStore.load())
        // The app reloads the timeline whenever it plans; otherwise refresh after local midnight so a stale card is labelled.
        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

struct TodayOutfitWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        Group {
            if let d = entry.data {
                let stale = !Calendar.current.isDateInToday(d.date)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(stale ? "Yesterday's card" : "Today").font(.caption).bold().foregroundStyle(stale ? .orange : .secondary)
                        Spacer()
                        Text(d.weatherLine).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    thumbnails(d)
                    if family != .systemSmall {
                        Text(d.rationale).font(.caption).lineLimit(2)
                        if let note = d.layeringNote { Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                    } else {
                        Text(d.slots.prefix(3).map(\.name).joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today").font(.caption).bold().foregroundStyle(.secondary)
                    Text("Open the app once to plan today's outfit.").font(.caption)
                }
            }
        }
        .widgetURL(URL(string: "wardrobestyler://today"))
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func thumbnails(_ d: TodayWidgetData) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(d.slots.prefix(family == .systemSmall ? 3 : 5).enumerated()), id: \.offset) { _, s in
                if let f = s.thumbnailFile, let url = WidgetStore.thumbnailURL(f), let ui = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: ui).resizable().scaledToFill().frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(.quaternary).frame(width: 40, height: 40).overlay(Text(String(s.name.prefix(1)).uppercased()).font(.caption2))
                }
            }
        }
    }
}

@main
struct TodayOutfitWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetStore.kind, provider: TodayProvider()) { entry in TodayOutfitWidgetView(entry: entry) }
            .configurationDisplayName("Today's outfit")
            .description("What to wear today, planned on your phone.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
