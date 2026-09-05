// Colour maths (PLAN §5.4, §5.6). Mirrors backend/src/domain/color.ts.
import Foundation

public struct Lab: Equatable, Sendable {
    public var L: Double, a: Double, b: Double
    public init(L: Double, a: Double, b: Double) { self.L = L; self.a = a; self.b = b }
    public var chroma: Double { (a * a + b * b).squareRoot() }
    public var hueDegrees: Double { let h = atan2(b, a) * 180 / .pi; return h < 0 ? h + 360 : h }
}

public enum ColorMath {
    public static func rgb(fromHex hex: String) -> (r: Double, g: Double, b: Double)? {
        var s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        s = ""
        return (Double((v >> 16) & 0xFF), Double((v >> 8) & 0xFF), Double(v & 0xFF))
    }

    public static func hex(r: Int, g: Int, b: Int) -> String { String(format: "#%02X%02X%02X", r, g, b) }

    private static func linear(_ c: Double) -> Double {
        let v = c / 255
        return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    public static func lab(r: Double, g: Double, b: Double) -> Lab {
        let rl = linear(r), gl = linear(g), bl = linear(b)
        let x = (rl * 0.4124564 + gl * 0.3575761 + bl * 0.1804375) / 0.95047
        let y = (rl * 0.2126729 + gl * 0.7151522 + bl * 0.072175) / 1.0
        let z = (rl * 0.0193339 + gl * 0.119192 + bl * 0.9503041) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16 / 116 }
        let fx = f(x), fy = f(y), fz = f(z)
        return Lab(L: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    public static func lab(hex: String) -> Lab? {
        guard let c = rgb(fromHex: hex) else { return nil }
        return lab(r: c.r, g: c.g, b: c.b)
    }

    /// CIEDE2000.
    public static func deltaE00(_ c1: Lab, _ c2: Lab) -> Double {
        func rad(_ d: Double) -> Double { d * .pi / 180 }
        func deg(_ r: Double) -> Double { r * 180 / .pi }
        let avgL = (c1.L + c2.L) / 2
        let C1 = c1.chroma, C2 = c2.chroma
        let avgC = (C1 + C2) / 2
        let G = 0.5 * (1 - (pow(avgC, 7) / (pow(avgC, 7) + pow(25, 7))).squareRoot())
        let a1p = c1.a * (1 + G), a2p = c2.a * (1 + G)
        let C1p = (a1p * a1p + c1.b * c1.b).squareRoot(), C2p = (a2p * a2p + c2.b * c2.b).squareRoot()
        let avgCp = (C1p + C2p) / 2
        func h(_ a: Double, _ b: Double) -> Double { if a == 0 && b == 0 { return 0 }; let v = deg(atan2(b, a)); return v < 0 ? v + 360 : v }
        let h1p = h(a1p, c1.b), h2p = h(a2p, c2.b)
        let avgHp: Double
        if C1p * C2p == 0 { avgHp = h1p + h2p }
        else if abs(h1p - h2p) <= 180 { avgHp = (h1p + h2p) / 2 }
        else { avgHp = h1p + h2p < 360 ? (h1p + h2p + 360) / 2 : (h1p + h2p - 360) / 2 }
        let T = 1 - 0.17 * cos(rad(avgHp - 30)) + 0.24 * cos(rad(2 * avgHp)) + 0.32 * cos(rad(3 * avgHp + 6)) - 0.2 * cos(rad(4 * avgHp - 63))
        let dhp: Double
        if C1p * C2p == 0 { dhp = 0 }
        else if abs(h2p - h1p) <= 180 { dhp = h2p - h1p }
        else { dhp = h2p - h1p > 180 ? h2p - h1p - 360 : h2p - h1p + 360 }
        let dLp = c2.L - c1.L, dCp = C2p - C1p
        let dHp = 2 * (C1p * C2p).squareRoot() * sin(rad(dhp) / 2)
        let SL = 1 + (0.015 * pow(avgL - 50, 2)) / (20 + pow(avgL - 50, 2)).squareRoot()
        let SC = 1 + 0.045 * avgCp
        let SH = 1 + 0.015 * avgCp * T
        let dTheta = 30 * exp(-pow((avgHp - 275) / 25, 2))
        let RC = 2 * (pow(avgCp, 7) / (pow(avgCp, 7) + pow(25, 7))).squareRoot()
        let RT = -RC * sin(rad(2 * dTheta))
        return (pow(dLp / SL, 2) + pow(dCp / SC, 2) + pow(dHp / SH, 2) + RT * (dCp / SC) * (dHp / SH)).squareRoot()
    }

    public static func nearestNamedColor(hex: String, palette: ColorPalette = .shared) -> (name: String, deltaE: Double) {
        guard let lab = lab(hex: hex) else { return ("other", .infinity) }
        var best = ("other", Double.infinity)
        for (name, h) in palette.named {
            guard let l = self.lab(hex: h) else { continue }
            let d = deltaE00(lab, l)
            if d < best.1 { best = (name, d) }
        }
        return best
    }

    public static func isNeutral(hex: String, palette: ColorPalette = .shared) -> Bool {
        guard let l = lab(hex: hex) else { return true }
        return l.chroma < palette.harmony.neutralChromaMax
    }

    /// 0–1 harmony against one reference colour (monochrome, analogous, complementary, neutral + accent).
    public static func harmonyScore(hex: String, reference: String, palette: ColorPalette = .shared) -> Double {
        let s = palette.harmony.scores
        guard let a = lab(hex: hex), let b = lab(hex: reference) else { return s.other }
        if a.chroma < palette.harmony.neutralChromaMax || b.chroma < palette.harmony.neutralChromaMax { return s.neutral }
        var dh = abs(a.hueDegrees - b.hueDegrees)
        if dh > 180 { dh = 360 - dh }
        if dh <= palette.harmony.monochromeHueDeg { return s.monochrome }
        if dh <= palette.harmony.analogousHueDeg { return s.analogous }
        if dh >= palette.harmony.complementaryMinDeg && dh <= palette.harmony.complementaryMaxDeg { return s.complementary }
        return s.other
    }

    public static func paletteScore(hex: String, references: [String], palette: ColorPalette = .shared) -> Double {
        if references.isEmpty { return palette.harmony.scores.neutral }
        return references.map { harmonyScore(hex: hex, reference: $0, palette: palette) }.max() ?? palette.harmony.scores.other
    }
}
