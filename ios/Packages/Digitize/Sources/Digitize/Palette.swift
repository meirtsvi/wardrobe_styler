// Colour from pixels (PLAN §5.4): k-means (k = 3) in CIELAB over masked pixels → primary/secondary hex + nearest of the 40 names.
import CoreGraphics
import Domain
import Foundation

public struct PaletteColor: Equatable, Sendable {
    public var hex: String
    public var name: String
    public var share: Double // fraction of masked pixels in this cluster
}

public enum Palette {
    /// `pixels` are RGBA8 samples of the masked garment (alpha ≥ 128 means garment). Deterministic seeding so results are stable across runs.
    public static func extract(rgba: [UInt8], k: Int = 3, maxSamples: Int = 4000, palette: ColorPalette = .shared) -> [PaletteColor] {
        var labs: [Lab] = []
        var rgbs: [(Double, Double, Double)] = []
        let count = rgba.count / 4
        let stride = max(1, count / maxSamples)
        var i = 0
        while i < count {
            let o = i * 4
            if rgba[o + 3] >= 128 {
                let r = Double(rgba[o]), g = Double(rgba[o + 1]), b = Double(rgba[o + 2])
                labs.append(ColorMath.lab(r: r, g: g, b: b))
                rgbs.append((r, g, b))
            }
            i += stride
        }
        guard !labs.isEmpty else { return [] }
        let kk = min(k, labs.count)

        // k-means++-style deterministic seeding: first = darkest-ish median, then farthest points.
        var centers: [Lab] = [labs[labs.count / 2]]
        while centers.count < kk {
            var far = labs[0]; var farD = -1.0
            for l in labs {
                let d = centers.map { ColorMath.deltaE00(l, $0) }.min() ?? 0
                if d > farD { farD = d; far = l }
            }
            centers.append(far)
        }
        var assignment = [Int](repeating: 0, count: labs.count)
        for _ in 0..<12 {
            for (idx, l) in labs.enumerated() {
                var best = 0; var bestD = Double.infinity
                for (c, center) in centers.enumerated() {
                    let d = (l.L - center.L) * (l.L - center.L) + (l.a - center.a) * (l.a - center.a) + (l.b - center.b) * (l.b - center.b)
                    if d < bestD { bestD = d; best = c }
                }
                assignment[idx] = best
            }
            var sums = Array(repeating: (L: 0.0, a: 0.0, b: 0.0, n: 0), count: kk)
            for (idx, l) in labs.enumerated() { let a = assignment[idx]; sums[a].L += l.L; sums[a].a += l.a; sums[a].b += l.b; sums[a].n += 1 }
            for c in 0..<kk where sums[c].n > 0 { centers[c] = Lab(L: sums[c].L / Double(sums[c].n), a: sums[c].a / Double(sums[c].n), b: sums[c].b / Double(sums[c].n)) }
        }

        var result: [PaletteColor] = []
        for c in 0..<kk {
            let members = assignment.enumerated().filter { $0.element == c }.map { rgbs[$0.offset] }
            guard !members.isEmpty else { continue }
            let r = Int((members.map { $0.0 }.reduce(0, +) / Double(members.count)).rounded())
            let g = Int((members.map { $0.1 }.reduce(0, +) / Double(members.count)).rounded())
            let b = Int((members.map { $0.2 }.reduce(0, +) / Double(members.count)).rounded())
            let hex = ColorMath.hex(r: r, g: g, b: b)
            result.append(PaletteColor(hex: hex, name: ColorMath.nearestNamedColor(hex: hex, palette: palette).name, share: Double(members.count) / Double(labs.count)))
        }
        return result.sorted { $0.share > $1.share }
    }

    /// Reads RGBA8 pixels from a CGImage (premultiplied alpha is fine for our thresholding).
    public static func rgba(from image: CGImage) -> [UInt8]? {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }
}
