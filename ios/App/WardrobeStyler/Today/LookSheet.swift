// "See it on me": the user's photo + the outfit's clothing cutouts → gateway try-on (ADR 0002, PLAN §4.13 consent + own-photo acknowledgement).
import Domain
import OnDeviceAI
import PhotosUI
import SwiftUI
import UIKit

struct LookSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let outfit: PlannedOutfit
    let records: [ItemRecord]

    @State private var pick: PhotosPickerItem?
    @State private var person: UIImage?
    @State private var acknowledged = false
    @State private var rendering = false
    @State private var result: UIImage?
    @State private var info: String?
    @State private var error: String?

    private var garments: [ItemRecord] {
        let wearable: Set<Slot> = [.onePiece, .top, .baseLayer, .midLayer, .outerwear, .bottom, .shoes]
        return outfit.slots.filter { wearable.contains($0.slot) }.compactMap { s in records.first { $0.id == s.itemId } }.prefix(4).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let result {
                        Image(uiImage: result).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                        if let info { Text(info).font(.caption).foregroundStyle(.secondary) }
                        Text("AI-generated image").font(.caption2).foregroundStyle(.tertiary)
                        Button("Save to Photos") { UIImageWriteToSavedPhotosAlbum(result, nil, nil, nil) }
                    } else {
                        PhotosPicker(selection: $pick, matching: .images) {
                            if let person {
                                Image(uiImage: person).resizable().scaledToFit().frame(maxHeight: 320).clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                ContentUnavailableView("Pick a photo of you", systemImage: "person.crop.rectangle", description: Text("Full body, standing, plain background works best."))
                            }
                        }
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(garments) { g in
                                    if let d = g.displayThumbnail, let ui = UIImage(data: d) { Image(uiImage: ui).resizable().scaledToFit().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 8)) }
                                }
                            }
                        }
                        Toggle("This is a photo of me, I'm over 18, and I'm fine sending it to Gemini for this render.", isOn: $acknowledged).font(.footnote)
                        Button { Task { await render() } } label: { Label(rendering ? "Rendering (≈ 25 s)…" : "Render", systemImage: "wand.and.stars").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).disabled(person == nil || !acknowledged || rendering || app.gateway == nil || garments.isEmpty)
                        if app.gateway == nil { Text("Set the Mac gateway in Me first.").font(.footnote).foregroundStyle(.orange) }
                        if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                    }
                }
                .padding()
            }
            .navigationTitle("See it on me")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .onChange(of: pick) { _, new in
                Task { if let new, let data = try? await new.loadTransferable(type: Data.self), let ui = UIImage(data: data) { person = ui } }
            }
        }
    }

    private func render() async {
        guard let gateway = app.gateway, let person, let cg = ImagePrep.normalised(person, longEdge: 1024), let personJPEG = ImagePrep.jpeg(cg, quality: 0.85) else { return }
        rendering = true
        defer { rendering = false }
        do {
            let inputs = garments.compactMap { g -> (image: InlineImage, label: String)? in
                guard let d = g.displayCutout else { return nil }
                return (InlineImage(mimeType: "image/jpeg", data: d), g.displayName)
            }
            let r = try await gateway.look(person: InlineImage(mimeType: "image/jpeg", data: personJPEG), garments: inputs)
            guard let bytes = r.image.bytes, let ui = UIImage(data: bytes) else { error = "Bad image from the gateway"; return }
            result = ui
            info = String(format: "%@ · %.0f s · ≈ $%.3f", r.model, Double(r.latency_ms) / 1000, r.cost_usd_est)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
