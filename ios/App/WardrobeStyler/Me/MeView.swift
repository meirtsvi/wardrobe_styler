// Me tab (ADR 0002): gateway settings, what runs where, spend today.
import Domain
import OnDeviceAI
import SwiftData
import SwiftUI

struct MeView: View {
    @Environment(AppModel.self) private var app
    @Query(filter: #Predicate<ItemRecord> { $0.deletedAt == nil }) private var records: [ItemRecord]
    @State private var url = ""
    @State private var token = ""
    @State private var testResult: String?
    @State private var testing = false

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section("Mac gateway") {
                    TextField("https://….trycloudflare.com", text: $url).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    SecureField("Token (GATEWAY_TOKEN)", text: $token)
                    HStack {
                        Button("Save") { app.settings = GatewaySettings(urlString: url, token: token); testResult = nil }
                        Spacer()
                        Button(testing ? "Testing…" : "Test") { Task { testing = true; testResult = await app.testGateway(); testing = false } }.disabled(testing || app.gateway == nil)
                    }
                    if let testResult { Text(testResult).font(.footnote).foregroundStyle(.secondary) }
                    Text("The URL changes each time scripts/run-mac.sh restarts the tunnel. Without a gateway the app is fully offline.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("On this phone") {
                    LabeledContent("Items", value: "\(records.count)")
                    LabeledContent("Named on device", value: "\(records.filter { $0.attributesSource == "device" }.count)")
                    LabeledContent("Named by Gemini", value: "\(records.filter { $0.attributesSource == "gemini" }.count)")
                    LabeledContent("Still unnamed", value: "\(records.filter { $0.attributesSource == "device_partial" }.count)")
                    LabeledContent("Local stylist model") {
                        switch app.localPlannerStatus {
                        case .available: Text("ready").foregroundStyle(.green)
                        case .unavailable(let r): Text(r).foregroundStyle(.secondary).font(.caption)
                        }
                    }
                }
                if let u = app.usage {
                    Section("Gemini spend today") {
                        LabeledContent("Estimated", value: String(format: "$%.3f of $%.2f", u.spent_today_usd, u.daily_budget_usd))
                        LabeledContent("Calls", value: "\(u.calls_today)")
                    }
                }
                Section {
                    Text("Photos stay on this phone except: a cutout sent to Gemini when the device cannot name it, and your own photo plus cutouts when you ask for a try-on. Colour is always measured from your photo.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Me")
            .onAppear { url = app.settings.urlString; token = app.settings.token }
            .refreshable { await app.refreshLocalPlannerStatus() }
        }
    }
}
