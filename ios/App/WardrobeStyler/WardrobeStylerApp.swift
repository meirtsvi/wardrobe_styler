// App shell (PLAN §6, ADR 0001). SwiftData is canonical for the wardrobe; every AI step runs on device first.
import SwiftData
import SwiftUI

@main
struct WardrobeStylerApp: App {
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: ItemRecord.self, WornEvent.self)
        } catch {
            fatalError("SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AppModel(container: container))
                .onAppear { DemoSeed.seedIfEmpty(container.mainContext) }
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") { TodayView() }
            Tab("Wardrobe", systemImage: "hanger") { WardrobeView() }
            Tab("Me", systemImage: "person.crop.circle") { MeView() }
        }
    }
}
