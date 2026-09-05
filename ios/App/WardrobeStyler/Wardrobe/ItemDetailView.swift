// Item detail + the review card's edits (PLAN §4.3 review queue, §4.4 item detail), wear stats, and the opt-in clean-up (PLAN §5.16).
import Domain
import OnDeviceAI
import SwiftData
import SwiftUI
import UIKit

struct ItemDetailView: View {
    @Bindable var item: ItemRecord
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var cleaning = false
    @State private var cleanupError: String?
    private let taxonomy = Taxonomy.shared

    var body: some View {
        Form {
            Section {
                if let data = item.displayCutout, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 280).frame(maxWidth: .infinity)
                }
                HStack {
                    Circle().fill(Color(hex: item.colorHex)).frame(width: 24, height: 24)
                    Text(item.colorName.replacingOccurrences(of: "_", with: " ")).textCase(nil)
                    Spacer()
                    Text("colour from pixels").font(.caption).foregroundStyle(.secondary)
                }
                if item.cleanedJPEG != nil {
                    Toggle("Show cleaned-up version", isOn: $item.useCleaned)
                } else {
                    Button { Task { await cleanUp() } } label: { Label(cleaning ? "Cleaning up…" : "Tidy background with Gemini", systemImage: "sparkles") }
                        .disabled(cleaning || app.gateway == nil || item.cutoutJPEG == nil)
                    if app.gateway == nil { Text("Needs the Mac gateway (Me tab).").font(.caption).foregroundStyle(.secondary) }
                }
                if let cleanupError { Text(cleanupError).font(.caption).foregroundStyle(.red) }
            }
            Section("What is it") {
                Picker("Category", selection: $item.category) {
                    ForEach(Domain.Category.allCases, id: \.rawValue) { Text($0.rawValue.replacingOccurrences(of: "_", with: " ")).tag($0.rawValue) }
                }
                Picker("Type", selection: $item.subcategory) {
                    ForEach(taxonomy.subcategories[item.category] ?? ["other"], id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) }
                }
                Picker("Warmth", selection: $item.warmth) { ForEach(Warmth.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
                Picker("Formality", selection: $item.formality) { ForEach(Formality.allCases, id: \.rawValue) { Text($0.rawValue.replacingOccurrences(of: "_", with: " ")).tag($0.rawValue) } }
                Picker("Material", selection: $item.material) { ForEach(taxonomy.materialsOrDefault, id: \.self) { Text($0).tag($0) } }
                if !item.caption.isEmpty { Text(item.caption).font(.footnote).foregroundStyle(.secondary) }
                LabeledContent("Named by", value: item.attributesSource.replacingOccurrences(of: "_", with: " "))
                if item.categoryConfidence > 0 {
                    LabeledContent("Confidence", value: item.categoryConfidence.formatted(.percent.precision(.fractionLength(0))))
                }
            }
            Section("Availability") {
                Picker("Status", selection: $item.availability) { ForEach(AvailabilityState.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
                Stepper("Quantity: \(item.quantity)", value: $item.quantity, in: 1...20)
                Toggle("Favourite", isOn: $item.favorite)
            }
            Section("Wear") {
                LabeledContent("Times worn", value: "\(item.wearCount)")
                LabeledContent("Last worn", value: item.lastWornOn.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "never")
                LabeledContent("Last suggested", value: item.lastSuggestedAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "never")
            }
            if item.status == "new" {
                Section {
                    Button("Looks right") { item.status = "confirmed"; save(); dismiss() }
                    Button("Not a garment", role: .destructive) { item.deletedAt = Date(); save(); dismiss() }
                }
            } else {
                Section { Button("Remove from wardrobe", role: .destructive) { item.deletedAt = Date(); save(); dismiss() } }
            }
        }
        .navigationTitle(item.displayName)
        .onChange(of: item.category) { _, new in
            if !(taxonomy.subcategories[new] ?? []).contains(item.subcategory) { item.subcategory = taxonomy.subcategories[new]?.first ?? "other" }
            item.layerRole = Domain.Category(rawValue: new).flatMap { taxonomy.defaultLayerRole(category: $0, subcategory: item.subcategory)?.rawValue }
        }
        .onDisappear { save() }
    }

    private func cleanUp() async {
        guard let gateway = app.gateway, let cutout = item.cutoutJPEG else { return }
        cleaning = true
        defer { cleaning = false }
        do {
            let img = try await gateway.cleanup(cutout: InlineImage(mimeType: "image/jpeg", data: cutout))
            guard let bytes = img.bytes, let ui = UIImage(data: bytes), let cg = ImagePrep.normalised(ui, longEdge: 1024) else { cleanupError = "Bad image from the gateway"; return }
            item.cleanedJPEG = ImagePrep.jpeg(cg, quality: 0.85)
            item.useCleaned = true
            cleanupError = nil
            save()
        } catch {
            cleanupError = error.localizedDescription
        }
    }

    private func save() {
        item.updatedAt = Date()
        try? context.save()
    }
}

extension Taxonomy {
    var materialsOrDefault: [String] { ["cotton", "denim", "wool", "knit", "leather", "silk", "linen", "synthetic", "unknown"] }
}
