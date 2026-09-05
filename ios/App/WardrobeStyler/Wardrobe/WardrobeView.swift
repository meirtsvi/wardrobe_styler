// Wardrobe grid + PhotosPicker digitisation (PLAN §4.3, §4.4; ADR 0001 on-device pipeline).
import Digitize
import Domain
import OnDeviceAI
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct WardrobeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<ItemRecord> { $0.deletedAt == nil }, sort: \ItemRecord.createdAt, order: .reverse) private var items: [ItemRecord]
    @State private var picked: [PhotosPickerItem] = []
    @State private var progress: (done: Int, total: Int)?
    @State private var lastError: String?

    private var reviewQueue: [ItemRecord] { items.filter { $0.status == "new" } }
    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView("No clothes yet", systemImage: "hanger", description: Text("Add photos of your clothes. Everything is cut out and colour-matched on this phone."))
                } else {
                    ScrollView {
                        if !reviewQueue.isEmpty {
                            Text("\(reviewQueue.count) to review").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(items) { item in
                                NavigationLink(value: item.id) { ItemTile(item: item) }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Wardrobe")
            .navigationDestination(for: String.self) { id in
                if let item = items.first(where: { $0.id == id }) { ItemDetailView(item: item) }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $picked, maxSelectionCount: 50, matching: .images) { Label("Add", systemImage: "plus") }
                }
            }
            .overlay(alignment: .bottom) {
                if let progress {
                    ProgressView(value: Double(progress.done), total: Double(progress.total)) { Text("Cutting out \(progress.done)/\(progress.total)") }
                        .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)).padding()
                }
            }
            .alert("Couldn't add photo", isPresented: Binding(get: { lastError != nil }, set: { if !$0 { lastError = nil } })) { Button("OK") {} } message: { Text(lastError ?? "") }
            .onChange(of: picked) { _, new in
                guard !new.isEmpty else { return }
                let batch = new
                picked = []
                Task { await ingest(batch) }
            }
        }
    }

    private func ingest(_ batch: [PhotosPickerItem]) async {
        progress = (0, batch.count)
        defer { progress = nil }
        let ingestor = Ingestor(app: app, context: context)
        for (i, pick) in batch.enumerated() {
            do {
                if let data = try await pick.loadTransferable(type: Data.self), let ui = UIImage(data: data) { try await ingestor.ingest(ui) }
            } catch {
                lastError = error.localizedDescription
            }
            progress = (i + 1, batch.count)
        }
    }
}

struct ItemTile: View {
    let item: ItemRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let data = item.displayThumbnail, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFit().frame(height: 120).clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10).fill(Color(hex: item.colorHex)).frame(height: 120)
                }
                if item.status == "new" { Image(systemName: "questionmark.circle.fill").foregroundStyle(.orange).padding(6) }
                if item.availability != "available" { Image(systemName: "washer").foregroundStyle(.secondary).padding(6) }
            }
            Text(item.displayName).font(.caption).lineLimit(1)
        }
        .accessibilityLabel(item.displayName)
    }
}

enum ImagePrep {
    /// Orientation-normalise and resize so the long edge is `longEdge` (PLAN §6 "Image pipeline on device"). EXIF is dropped by re-encoding.
    static func normalised(_ image: UIImage, longEdge: CGFloat) -> CGImage? {
        let scale = min(1, longEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return out.cgImage
    }
    static func jpeg(_ cg: CGImage, quality: CGFloat) -> Data? { UIImage(cgImage: cg).jpegData(compressionQuality: quality) }
}

extension Color {
    init(hex: String) {
        let c = ColorMath.rgb(fromHex: hex) ?? (140, 140, 140)
        self.init(red: c.r / 255, green: c.g / 255, blue: c.b / 255)
    }
}
