// App-wide services (PLAN §6 MVVM with @Observable). Local planner first, gateway second, combiner last (ADR 0001).
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
    let orchestrator: PlanOrchestrator
    var localPlannerStatus: PlannerAvailability = .unavailable(reason: "checking")
    var gatewayConfigured: Bool

    /// Set `GATEWAY_URL` in the scheme environment to enable the Gemini fallback; without it the app is fully offline.
    init(container: ModelContainer) {
        self.container = container
        var planners: [any OutfitPlanner] = [LocalPlanner()]
        if let urlString = ProcessInfo.processInfo.environment["GATEWAY_URL"], let url = URL(string: urlString) {
            planners.append(GatewayPlanner(client: GatewayClient(baseURL: url, tokens: DevTokens())))
            gatewayConfigured = true
        } else {
            gatewayConfigured = false
        }
        orchestrator = PlanOrchestrator(planners: planners)
        Task { await refreshLocalPlannerStatus() }
    }

    func refreshLocalPlannerStatus() async {
        localPlannerStatus = await LocalPlanner().availability()
    }
}

/// Development tokens matching the gateway's StaticVerifier (GATEWAY_STATIC_AUTH=1). Firebase Auth + App Check replace this in Phase 3.
struct DevTokens: TokenProvider {
    func idToken() async throws -> String { "uid:dev-\(DevTokens.deviceId)" }
    func appCheckToken(limitedUse: Bool) async throws -> String { "dev" }
    static let deviceId: String = {
        let key = "dev.device.id"
        if let v = UserDefaults.standard.string(forKey: key) { return v }
        let v = UUID().uuidString.lowercased()
        UserDefaults.standard.set(v, forKey: key)
        return v
    }()
}
