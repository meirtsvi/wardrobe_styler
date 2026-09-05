// Typed client for the Cloud Run gateway (PLAN §6 "Gateway" module, ADR 0001). Firebase ID + App Check tokens come from `TokenProvider`.
import Domain
import Foundation

public protocol TokenProvider: Sendable {
    func idToken() async throws -> String
    func appCheckToken(limitedUse: Bool) async throws -> String
}

public struct GatewayError: Error, Equatable, Sendable {
    public var status: Int
    public var code: String
    public var message: String
    public var retryAfter: [String: Double]?
}

public struct MeResponse: Codable, Equatable, Sendable {
    public struct Looks: Codable, Equatable, Sendable { public var plan: Int; public var purchased: Int; public var renews_at: Double? }
    public var uid: String
    public var plan: String
    public var looks: Looks
    public var flags: [String: Bool]?
    public var exists: Bool
}

public struct JobResponse: Codable, Equatable, Sendable {
    public var id: String
    public var status: String
    public var queue: String
    public var credits_charged: Int
    public var bucket_charged: String?
}

public struct RemotePlanResponse: Codable, Sendable {
    public struct Outfit: Codable, Sendable {
        public var slots: [PlannedSlot]
        public var rationale: String
        public var weather_fit: WeatherFit
        public var formality: Formality
        public var palette: [String]
        public var layering_note: String?
        public var confidence: Double
    }
    public var outfits: [Outfit]
    public var anchor_honored: Bool
    public var anchor_reason: String?
}

public final class GatewayClient: Sendable {
    private let baseURL: URL
    private let tokens: any TokenProvider
    private let session: URLSession

    public init(baseURL: URL, tokens: any TokenProvider, session: URLSession = .shared) {
        self.baseURL = baseURL; self.tokens = tokens; self.session = session
    }

    public func me() async throws -> MeResponse { try await request("GET", "/v1/me", body: Optional<Int>.none, limitedUse: false) }

    /// Metered job types consume a limited-use App Check token (PLAN §7.2). `idempotencyKey` must be a UUID and is stored by the caller until acknowledged.
    public func createJob(type: String, input: [String: AnyCodable], idempotencyKey: UUID, metered: Bool) async throws -> JobResponse {
        try await request("POST", "/v1/jobs", body: ["type": AnyCodable(type), "input": AnyCodable(input)], limitedUse: metered,
                          headers: ["Idempotency-Key": idempotencyKey.uuidString.lowercased()])
    }

    public func cancelJob(id: String) async throws -> JobResponse {
        try await request("POST", "/v1/jobs/\(id)/cancel", body: Optional<Int>.none, limitedUse: false)
    }

    /// Gemini Stage B via the gateway; the client sends its Stage A candidates (ADR 0001: the server never reads the wardrobe).
    public func planOutfits(_ call: PlannerCall) async throws -> PlanResponse {
        let r: RemotePlanResponse = try await request("POST", "/v1/outfits/plan", body: PlannerPayload.body(for: call), limitedUse: false,
                                                     headers: ["X-Plan-N": String(call.n)])
        return PlanResponse(
            outfits: r.outfits.map { PlannedOutfit(slots: $0.slots, rationale: $0.rationale, weatherFit: $0.weather_fit, formality: $0.formality, palette: $0.palette, layeringNote: $0.layering_note, confidence: $0.confidence) },
            anchorHonored: r.anchor_honored, anchorReason: r.anchor_reason)
    }

    private func request<B: Encodable, R: Decodable>(_ method: String, _ path: String, body: B?, limitedUse: Bool, headers: [String: String] = [:]) async throws -> R {
        var req = URLRequest(url: baseURL.appending(path: path))
        req.httpMethod = method
        req.setValue("Bearer \(try await tokens.idToken())", forHTTPHeaderField: "Authorization")
        req.setValue(try await tokens.appCheckToken(limitedUse: limitedUse), forHTTPHeaderField: "X-Firebase-AppCheck")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let body { req.httpBody = try JSONEncoder().encode(body) }
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let e = try? JSONDecoder().decode(GatewayErrorBody.self, from: data)
            throw GatewayError(status: status, code: e?.error ?? "http_\(status)", message: e?.message ?? "request failed", retryAfter: e?.retry_after)
        }
        return try JSONDecoder().decode(R.self, from: data)
    }
}

struct GatewayErrorBody: Decodable { var error: String?; var message: String?; var retry_after: [String: Double]? }

/// Remote planner wrapper so the orchestrator can chain local → gateway.
public struct GatewayPlanner: OutfitPlanner {
    public let name = "gemini_gateway"
    private let client: GatewayClient
    private let reachable: @Sendable () async -> Bool
    public init(client: GatewayClient, reachable: @escaping @Sendable () async -> Bool = { true }) { self.client = client; self.reachable = reachable }
    public func availability() async -> PlannerAvailability { await reachable() ? .available : .unavailable(reason: "offline") }
    public func plan(_ call: PlannerCall) async throws -> PlanResponse { try await client.planOutfits(call) }
}

/// Minimal type-erased JSON value for job inputs.
public struct AnyCodable: Codable, Sendable {
    public let value: any Sendable
    public init(_ value: any Sendable) { self.value = value }
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { value = v }
        else if let v = try? c.decode(Int.self) { value = v }
        else if let v = try? c.decode(Double.self) { value = v }
        else if let v = try? c.decode(String.self) { value = v }
        else if let v = try? c.decode([AnyCodable].self) { value = v.map(\.value) }
        else if let v = try? c.decode([String: AnyCodable].self) { value = v.mapValues(\.value) }
        else { value = Optional<String>.none as Any as! any Sendable }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try c.encode(v)
        case let v as Int: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String: try c.encode(v)
        case let v as [any Sendable]: try c.encode(v.map(AnyCodable.init))
        case let v as [String: any Sendable]: try c.encode(v.mapValues(AnyCodable.init))
        case let v as AnyCodable: try c.encode(v)
        default: try c.encodeNil()
        }
    }
}
