// Typed client for the personal gateway on the Mac mini (ADR 0002): one bearer token, JSON in, JSON out.
import Domain
import Foundation

public struct GatewayError: Error, Equatable, Sendable, LocalizedError {
    public var status: Int
    public var code: String
    public var message: String
    public var errorDescription: String? { "\(message) (\(code))" }
}

public struct InlineImage: Codable, Equatable, Sendable {
    public var mime_type: String
    public var data: String // base64
    public init(mimeType: String, data: Data) { self.mime_type = mimeType; self.data = data.base64EncodedString() }
    public var bytes: Data? { Data(base64Encoded: data) }
}

public struct UsageResponse: Codable, Equatable, Sendable {
    public var spent_today_usd: Double
    public var calls_today: Int
    public var daily_budget_usd: Double
    public var models: [String: String]
}

public struct HealthResponse: Codable, Equatable, Sendable { public var ok: Bool; public var gemini: Bool; public var images: Bool }

public struct AttributesResponse: Codable, Sendable {
    public struct Attributes: Codable, Sendable {
        public var category: String, subcategory: String, layer_role: String?, primary_color_name: String, secondary_colors: [String]
        public var pattern: String, material: String, fit: String, length: String, warmth: String, season: [String], formality: String, occasions: [String]
        public var brand_guess: String?, brand_confidence: Double, field_confidences: [String: Double], caption: String
    }
    public var attributes: Attributes
    public var model: String
}

public struct LookResponse: Codable, Sendable {
    public var image: InlineImage
    public var model: String
    public var latency_ms: Int
    public var cost_usd_est: Double
    public var note: String?
}

public struct RemotePlanResponse: Codable, Sendable {
    public struct Outfit: Codable, Sendable {
        public var slots: [PlannedSlot]; public var rationale: String; public var weather_fit: WeatherFit; public var formality: Formality
        public var palette: [String]; public var layering_note: String?; public var confidence: Double
    }
    public var outfits: [Outfit]
    public var anchor_honored: Bool
    public var anchor_reason: String?
    public var planner: String?
}

public final class GatewayClient: Sendable {
    public let baseURL: URL
    private let token: String
    private let session: URLSession

    public init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL; self.token = token; self.session = session
    }

    public func health() async throws -> HealthResponse { try await request("GET", "/healthz", body: Optional<Int>.none) }
    public func usage() async throws -> UsageResponse { try await request("GET", "/v1/usage", body: Optional<Int>.none) }

    /// Gemini Stage B via the gateway; the client sends its Stage A candidates.
    public func planOutfits(_ call: PlannerCall) async throws -> PlanResponse {
        let r: RemotePlanResponse = try await request("POST", "/v1/outfits/plan", body: PlannerPayload.body(for: call), headers: ["X-Plan-N": String(call.n)])
        return PlanResponse(
            outfits: r.outfits.map { PlannedOutfit(slots: $0.slots, rationale: $0.rationale, weatherFit: $0.weather_fit, formality: $0.formality, palette: $0.palette, layeringNote: $0.layering_note, confidence: $0.confidence) },
            anchorHonored: r.anchor_honored, anchorReason: r.anchor_reason)
    }

    /// Names a garment the device could not (ADR 0001 "What the device classifier can and cannot see").
    public func attributes(cutout: InlineImage, primaryHex: String, primaryName: String, secondaryHex: [String], detectionLabel: String?, accurate: Bool = false) async throws -> AttributesResponse {
        struct Body: Encodable { var image: InlineImage; var pixel_palette: Palette; var detection_label: String?; var accurate: Bool
            struct Palette: Encodable { var primary_hex: String; var primary_name: String; var secondary_hex: [String] } }
        return try await request("POST", "/v1/items/attributes", body: Body(image: cutout, pixel_palette: .init(primary_hex: primaryHex, primary_name: primaryName, secondary_hex: secondaryHex), detection_label: detectionLabel, accurate: accurate), timeout: 60)
    }

    /// Virtual try-on: the user's photo + up to 4 garment cutouts → one composed image (~25 s).
    public func look(person: InlineImage, garments: [(image: InlineImage, label: String)], imageSize: String = "1K", notes: String? = nil) async throws -> LookResponse {
        struct Garment: Encodable { var image: InlineImage; var label: String }
        struct Body: Encodable { var person: InlineImage; var garments: [Garment]; var image_size: String; var notes: String? }
        return try await request("POST", "/v1/looks", body: Body(person: person, garments: garments.map { Garment(image: $0.image, label: $0.label) }, image_size: imageSize, notes: notes), timeout: 180)
    }

    private func request<B: Encodable, R: Decodable>(_ method: String, _ path: String, body: B?, headers: [String: String] = [:], timeout: TimeInterval = 30) async throws -> R {
        var req = URLRequest(url: baseURL.appending(path: path), timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let body { req.httpBody = try JSONEncoder().encode(body) }
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let e = try? JSONDecoder().decode(GatewayErrorBody.self, from: data)
            throw GatewayError(status: status, code: e?.error ?? "http_\(status)", message: e?.message ?? "request failed")
        }
        return try JSONDecoder().decode(R.self, from: data)
    }
}

struct GatewayErrorBody: Decodable { var error: String?; var message: String? }

/// Remote planner wrapper so the orchestrator can chain local → gateway.
public struct GatewayPlanner: OutfitPlanner {
    public let name = "gemini_gateway"
    private let client: GatewayClient
    public init(client: GatewayClient) { self.client = client }
    public func availability() async -> PlannerAvailability { .available }
    public func plan(_ call: PlannerCall) async throws -> PlanResponse { try await client.planOutfits(call) }
}
