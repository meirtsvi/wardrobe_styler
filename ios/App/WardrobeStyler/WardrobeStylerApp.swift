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

    let appModel: AppModel

    init() { appModel = AppModel(container: container) }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .onAppear { DemoSeed.seedIfEmpty(container.mainContext) }
                .task { await ingestDebugFiles() }
        }
        .modelContainer(container)
    }
}

extension WardrobeStylerApp {
    /// Debug: ingest files named by `--ingest-file` once per launch through the same pipeline as the picker.
    @MainActor func ingestDebugFiles() async {
        let files = Ingestor.debugFiles()
        guard !files.isEmpty else { return }
        let ingestor = Ingestor(app: appModel, context: container.mainContext)
        for f in files {
            guard let ui = UIImage(contentsOfFile: f) else { print("[ingest-file] cannot read \(f)"); continue }
            do { let n = try await ingestor.ingest(ui); print("[ingest-file] \(f): stored \(n)") } catch { print("[ingest-file] \(f): \(error)") }
        }
    }
}

struct RootView: View {
    /// Debug: `--tab wardrobe|me` selects the initial tab for simulator screenshots.
    @State private var selection: String = {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "--tab"), a.indices.contains(i + 1) { return a[i + 1] }
        return "today"
    }()
    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "sun.max", value: "today") { TodayView() }
            Tab("Wardrobe", systemImage: "hanger", value: "wardrobe") { WardrobeView() }
            Tab("Me", systemImage: "person.crop.circle", value: "me") { MeView() }
        }
        .onOpenURL { url in
            if url.scheme == "wardrobestyler", let host = url.host(), ["today", "wardrobe", "me"].contains(host) { selection = host }
        }
    }
}
