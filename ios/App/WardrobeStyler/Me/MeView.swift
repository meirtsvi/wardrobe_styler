// Me tab (PLAN §4.14): what runs where, privacy posture, and the gateway/Looks status when a gateway is configured.
import Domain
import OnDeviceAI
import SwiftData
import SwiftUI

struct MeView: View {
    @Environment(AppModel.self) private var app
    @Query(filter: #Predicate<ItemRecord> { $0.deletedAt == nil }) private var records: [ItemRecord]

    var body: some View {
        NavigationStack {
            List {
                Section("On this phone") {
                    LabeledContent("Items", value: "\(records.count)")
                    LabeledContent("Cut out on device", value: "\(records.filter { $0.source == "photo" }.count)")
                    LabeledContent("Named by the device", value: "\(records.filter { $0.attributesSource == "device" }.count)")
                    LabeledContent("Need a cloud look", value: "\(records.filter { $0.attributesSource == "device_partial" }.count)")
                    LabeledContent("Local stylist model") {
                        switch app.localPlannerStatus {
                        case .available: Text("ready").foregroundStyle(.green)
                        case .unavailable(let r): Text(r).foregroundStyle(.secondary).font(.caption)
                        }
                    }
                }
                Section("Cloud") {
                    LabeledContent("Gemini gateway", value: app.gatewayConfigured ? "configured" : "off (fully offline)")
                    Text("Photos never leave this phone unless a garment cannot be named on device or you ask for a try-on. Colour is always measured from your photo.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Looks") {
                    Text("Virtual try-on arrives in 1.0.5 (PLAN §4.13). Balances will show here in Looks.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Me")
            .refreshable { await app.refreshLocalPlannerStatus() }
        }
    }
}
