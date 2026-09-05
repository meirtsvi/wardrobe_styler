// App-wide services (PLAN §6 MVVM with @Observable). Local planner first, the Mac gateway second, combiner last (ADR 0001, 0002).
import Digitize
import Domain
import Foundation
import OnDeviceAI
import SwiftData
import SwiftUI

@Observable
final class AppModel {
    let container: ModelContainer
    let digitizer = GarmentDigitizer()
    var settings = GatewaySettings.load() { didSet { settings.save(); rebuild() } }
    private(set) var orchestrator: PlanOrchestrator
    private(set) var gateway: GatewayClient?
    var localPlannerStatus: PlannerAvailability = .unavailable(reason: "checking")
    var gatewayHealth: HealthResponse?
    var usage: UsageResponse?

    init(container: ModelContainer) {
        self.container = container
        let s = GatewaySettings.load()
        self.gateway = s.client
        self.orchestrator = PlanOrchestrator(planners: [LocalPlanner()] + (s.client.map { [GatewayPlanner(client: $0)] } ?? []))
        Task { await refreshLocalPlannerStatus() }
    }

    private func rebuild() {
        gateway = settings.client
        orchestrator = PlanOrchestrator(planners: [LocalPlanner()] + (gateway.map { [GatewayPlanner(client: $0)] } ?? []))
        gatewayHealth = nil; usage = nil
    }

    func refreshLocalPlannerStatus() async { localPlannerStatus = await LocalPlanner().availability() }

    func testGateway() async -> String {
        guard let gateway else { return "No gateway configured." }
        do {
            gatewayHealth = try await gateway.health()
            usage = try await gateway.usage()
            let h = gatewayHealth!
            return "Connected. Gemini \(h.gemini ? "on" : "off"), images \(h.images ? "on" : "off"). Spent today $\(String(format: "%.2f", usage?.spent_today_usd ?? 0)) of $\(String(format: "%.2f", usage?.daily_budget_usd ?? 0))."
        } catch {
            gatewayHealth = nil
            return "Failed: \(error.localizedDescription)"
        }
    }
}

/// Gateway URL + token from the app's Settings (ADR 0002: a quick-tunnel URL that changes per run). Stored in UserDefaults on this personal build.
struct GatewaySettings: Equatable {
    var urlString: String = ""
    var token: String = ""

    var client: GatewayClient? {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)), url.scheme?.hasPrefix("http") == true, !token.isEmpty else { return nil }
        return GatewayClient(baseURL: url, token: token)
    }

    static func load() -> GatewaySettings {
        let d = UserDefaults.standard
        var s = GatewaySettings(urlString: d.string(forKey: "gateway.url") ?? "", token: d.string(forKey: "gateway.token") ?? "")
        // Dev convenience: scheme environment overrides.
        let env = ProcessInfo.processInfo.environment
        if let u = env["GATEWAY_URL"], !u.isEmpty { s.urlString = u }
        if let t = env["GATEWAY_TOKEN"], !t.isEmpty { s.token = t }
        return s
    }

    func save() {
        UserDefaults.standard.set(urlString, forKey: "gateway.url")
        UserDefaults.standard.set(token, forKey: "gateway.token")
    }
}
