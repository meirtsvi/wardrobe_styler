// Item detail + the review card's edits (PLAN §4.3 review queue, §4.4 item detail). Every field the client owns is editable here.
import Domain
import SwiftData
import SwiftUI
import UIKit

struct ItemDetailView: View {
    @Bindable var item: ItemRecord
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    private let taxonomy = Taxonomy.shared

    var body: some View {
        Form {
            Section {
                if let data = item.cutoutJPEG, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 280).frame(maxWidth: .infinity)
                }
                HStack {
                    Circle().fill(Color(hex: item.colorHex)).frame(width: 24, height: 24)
                    Text(item.colorName.replacingOccurrences(of: "_", with: " ")).textCase(nil)
                    Spacer()
                    Text("colour from pixels").font(.caption).foregroundStyle(.secondary)
                }
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
                if item.categoryConfidence > 0 {
                    LabeledContent("Device confidence", value: item.categoryConfidence.formatted(.percent.precision(.fractionLength(0))))
                }
            }
            Section("Availability") {
                Picker("Status", selection: $item.availability) { ForEach(AvailabilityState.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
                Stepper("Quantity: \(item.quantity)", value: $item.quantity, in: 1...20)
                Toggle("Favourite", isOn: $item.favorite)
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

    private func save() {
        item.updatedAt = Date()
        try? context.save()
    }
}

extension Taxonomy {
    var materialsOrDefault: [String] { ["cotton", "denim", "wool", "knit", "leather", "silk", "linen", "synthetic", "unknown"] }
}
