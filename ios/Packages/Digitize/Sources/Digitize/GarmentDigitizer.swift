// On-device digitisation (ADR 0001, PLAN §5.1–5.5): Vision instance masks → per-instance cutouts on white → palette → classifier guess → feature print.
// Anything the device cannot settle is flagged `needsCloudAttributes` for the Gemini Lite fallback; the cutout stays real pixels either way.
import CoreGraphics
import CoreImage
import Domain
import Foundation
import Vision

public struct DetectedGarment: Sendable {
    public var index: Int
    /// Normalised bounding box in image coordinates (origin top-left, 0–1).
    public var box: CGRect
    public var cutout: CGImage
    public var thumbnail: CGImage
    public var maskCoverage: Double // masked pixels / box pixels
    public var palette: [PaletteColor]
    public var classifierLabels: [(identifier: String, confidence: Float)]
    public var categoryGuess: CategoryGuess?
    public var garmentScore: Float
    public var featurePrint: FeaturePrint?
    public var needsCloudAttributes: Bool
}

public struct FeaturePrint: Sendable {
    let observation: FeaturePrintObservation
    public func distance(to other: FeaturePrint) throws -> Double { Double(try observation.distance(to: other.observation)) }
}

public struct DigitizeOptions: Sendable {
    public var maxInstances = 25
    public var minBoxAreaFraction = 0.02      // PLAN §5.1: drop boxes < 2 % of image area
    public var minMaskCoverage = 0.6          // below this the Gemini segmentation fallback is preferred
    public var thumbnailLongEdge = 256
    public var cutoutLongEdge = 1024
    public init() {}
}

public enum DigitizeError: Error { case noPixels, contextFailed }

public struct GarmentDigitizer: Sendable {
    private let options: DigitizeOptions
    public init(options: DigitizeOptions = DigitizeOptions()) { self.options = options }

    /// Whole-image person count for the try-on gate and the "worn by person" routing (a person mask means route the garments to Gemini segmentation).
    public func personCount(in image: CGImage) async throws -> Int {
        guard let result = try await GeneratePersonInstanceMaskRequest().perform(on: image) else { return 0 }
        return result.allInstances.count
    }

    public func digitize(_ image: CGImage) async throws -> [DetectedGarment] {
        let handler = ImageRequestHandler(image)
        guard let masks = try await GenerateForegroundInstanceMaskRequest().perform(on: image) else { return [] }
        var results: [DetectedGarment] = []

        for (i, instance) in masks.allInstances.sorted().prefix(options.maxInstances).enumerated() {
            // Masked image with transparent background, cropped to the instance extent.
            let masked = try masks.generateMaskedImage(for: [instance], imageFrom: handler, croppedToInstancesExtent: true)
            let maskedCG = try Self.cgImage(from: masked)
            let extent = try Self.instanceExtent(masks: masks, instance: instance, handler: handler) ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            let boxArea = extent.width * extent.height
            if boxArea < options.minBoxAreaFraction { continue }

            let rgba = Palette.rgba(from: maskedCG) ?? []
            let coverage = Self.coverage(rgba: rgba)
            let palette = Palette.extract(rgba: rgba)
            let cutout = try Self.composite(onWhite: maskedCG, longEdge: options.cutoutLongEdge)
            let thumb = try Self.composite(onWhite: maskedCG, longEdge: options.thumbnailLongEdge)

            let labels = try await Self.classify(cutout)
            let guess = LabelMapping.guess(from: labels)
            let garmentScore = LabelMapping.looksLikeGarment(labels)
            let print = try? await Self.featurePrint(cutout)
            let settled = (guess?.confidence ?? 0) >= LabelMapping.settleThreshold && guess?.subcategory != nil

            results.append(DetectedGarment(
                index: i, box: extent, cutout: cutout, thumbnail: thumb, maskCoverage: coverage, palette: palette,
                classifierLabels: labels, categoryGuess: guess, garmentScore: garmentScore, featurePrint: print,
                needsCloudAttributes: !settled || coverage < options.minMaskCoverage))
        }
        return results
    }

    // MARK: - helpers

    static func classify(_ image: CGImage) async throws -> [(identifier: String, confidence: Float)] {
        let obs = try await ClassifyImageRequest().perform(on: image)
        return obs.filter { $0.confidence >= 0.05 }.prefix(12).map { ($0.identifier, $0.confidence) }
    }

    static func featurePrint(_ image: CGImage) async throws -> FeaturePrint {
        FeaturePrint(observation: try await GenerateImageFeaturePrintRequest().perform(on: image))
    }

    static func instanceExtent(masks: InstanceMaskObservation, instance: Int, handler: ImageRequestHandler) throws -> CGRect? {
        // Scaled mask → bounding box of pixels above 0.5, normalised to the image with a top-left origin.
        let mask = try masks.generateScaledMask(for: [instance], scaledToImageFrom: handler)
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        let w = CVPixelBufferGetWidth(mask), h = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let format = CVPixelBufferGetPixelFormatType(mask)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = base.advanced(by: y * rowBytes)
            for x in 0..<w {
                let on: Bool
                if format == kCVPixelFormatType_OneComponent32Float {
                    on = row.load(fromByteOffset: x * 4, as: Float.self) > 0.5
                } else {
                    on = row.load(fromByteOffset: x, as: UInt8.self) > 127
                }
                if on { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: CGFloat(minX) / CGFloat(w), y: CGFloat(minY) / CGFloat(h), width: CGFloat(maxX - minX + 1) / CGFloat(w), height: CGFloat(maxY - minY + 1) / CGFloat(h))
    }

    static func coverage(rgba: [UInt8]) -> Double {
        let count = rgba.count / 4
        guard count > 0 else { return 0 }
        var on = 0
        var i = 3
        while i < rgba.count { if rgba[i] >= 128 { on += 1 }; i += 4 }
        return Double(on) / Double(count)
    }

    static func cgImage(from buffer: CVPixelBuffer) throws -> CGImage {
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let cg = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(ci, from: ci.extent) else { throw DigitizeError.contextFailed }
        return cg
    }

    /// Composite a transparent cutout over white and resize so the long edge is `longEdge` (PLAN §5.2 "white composite").
    static func composite(onWhite image: CGImage, longEdge: Int) throws -> CGImage {
        let scale = min(1, CGFloat(longEdge) / CGFloat(max(image.width, image.height)))
        let w = max(1, Int(CGFloat(image.width) * scale)), h = max(1, Int(CGFloat(image.height) * scale))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw DigitizeError.contextFailed }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let out = ctx.makeImage() else { throw DigitizeError.contextFailed }
        return out
    }
}

public enum Similarity {
    /// Feature-print distance below which two cutouts are treated as the same garment (tune on the golden set; PLAN §5.5 duplicate sheet).
    public static let duplicateThreshold: Double = 0.35
    public static func isDuplicate(_ a: FeaturePrint, _ b: FeaturePrint) -> Bool { ((try? a.distance(to: b)) ?? .infinity) < duplicateThreshold }
}
