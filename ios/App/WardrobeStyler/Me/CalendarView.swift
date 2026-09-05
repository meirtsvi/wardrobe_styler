// Month calendar over the wear log (PLAN §4.11 calendar / planner, v1.1 wear log): dots on days with wear events; tap a day to see the items.
import SwiftData
import SwiftUI
import UIKit

struct CalendarView: View {
    @Query(sort: \WornEvent.date) private var events: [WornEvent]
    @Query(filter: #Predicate<ItemRecord> { $0.deletedAt == nil }) private var records: [ItemRecord]
    @State private var month: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selected: Date? = Calendar.current.startOfDay(for: Date())

    private var cal: Calendar { Calendar.current }
    private var eventsByDay: [Date: [WornEvent]] { Dictionary(grouping: events) { cal.startOfDay(for: $0.date) } }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { month = cal.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                Spacer()
                Button { month = cal.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal)

            let symbols = cal.veryShortStandaloneWeekdaySymbols
            let firstWeekday = cal.firstWeekday
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(0..<7, id: \.self) { i in Text(symbols[(i + firstWeekday - 1) % 7]).font(.caption2).foregroundStyle(.secondary) }
                ForEach(cells(), id: \.self) { day in
                    if let day {
                        let worn = eventsByDay[day] ?? []
                        Button { selected = day } label: {
                            VStack(spacing: 3) {
                                Text("\(cal.component(.day, from: day))").font(.callout).fontWeight(cal.isDateInToday(day) ? .bold : .regular)
                                Circle().fill(worn.isEmpty ? .clear : Color.accentColor).frame(width: 6, height: 6)
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(selected == day ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(minHeight: 40)
                    }
                }
            }
            .padding(.horizontal)

            if let selected {
                let worn = eventsByDay[selected] ?? []
                List {
                    Section(selected.formatted(date: .complete, time: .omitted)) {
                        if worn.isEmpty { Text("Nothing logged.").foregroundStyle(.secondary) }
                        ForEach(worn, id: \.persistentModelID) { e in
                            HStack(spacing: 12) {
                                if let r = records.first(where: { $0.id == e.itemId }), let d = r.displayThumbnail, let ui = UIImage(data: d) {
                                    Image(uiImage: ui).resizable().scaledToFit().frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                Text(records.first(where: { $0.id == e.itemId })?.displayName ?? e.itemId)
                                Spacer()
                                if e.toLaundry { Image(systemName: "washer").foregroundStyle(.secondary) }
                            }
                        }
                    }
                    let monthEvents = events.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
                    Section("This month") {
                        LabeledContent("Days dressed", value: "\(Set(monthEvents.map { cal.startOfDay(for: $0.date) }).count)")
                        LabeledContent("Items worn", value: "\(Set(monthEvents.map(\.itemId)).count)")
                        if let top = Dictionary(grouping: monthEvents, by: \.itemId).max(by: { $0.value.count < $1.value.count }) {
                            LabeledContent("Most worn", value: "\(records.first { $0.id == top.key }?.displayName ?? top.key) (\(top.value.count)×)")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Calendar")
    }

    /// Leading blanks + every day of the month.
    private func cells() -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let weekdayOfFirst = cal.component(.weekday, from: month)
        let leading = (weekdayOfFirst - cal.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + range.map { cal.date(byAdding: .day, value: $0 - 1, to: month) }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date { self.date(from: dateComponents([.year, .month], from: date))! }
}
