import CoreGraphics
import Domain
import Foundation
import Testing
import Vision
@testable import Digitize

enum TestImages {
    /// A solid colour rectangle centred on white with an alpha mask where the rectangle is.
    static func rgba(width: Int, height: Int, rect: CGRect, r: UInt8, g: UInt8, b: UInt8) -> [UInt8] {
        var px = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let o = (y * width + x) * 4
                if rect.contains(CGPoint(x: x, y: y)) { px[o] = r; px[o + 1] = g; px[o + 2] = b; px[o + 3] = 255 }
                else { px[o] = 255; px[o + 1] = 255; px[o + 2] = 255; px[o + 3] = 0 }
            }
        }
        return px
    }

    static func cgImage(width: Int, height: Int, rect: CGRect, r: UInt8, g: UInt8, b: UInt8, opaqueBackground: Bool) -> CGImage {
        var px = rgba(width: width, height: height, rect: rect, r: r, g: g, b: b)
        if opaqueBackground { var i = 3; while i < px.count { px[i] = 255; i += 4 } }
        let ctx = CGContext(data: &px, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }
}

@Suite struct PaletteTests {
    @Test func navyRectangleIsNavy() {
        let px = TestImages.rgba(width: 64, height: 64, rect: CGRect(x: 16, y: 16, width: 32, height: 32), r: 0x1F, g: 0x2A, b: 0x44)
        let p = Palette.extract(rgba: px)
        #expect(p.first?.name == "navy")
        #expect(p.first?.share ?? 0 > 0.9)
    }

    @Test func twoColourGarmentGivesTwoClusters() {
        var px = TestImages.rgba(width: 64, height: 64, rect: CGRect(x: 0, y: 0, width: 64, height: 32), r: 0xC4, g: 0x2B, b: 0x2B)
        let lower = TestImages.rgba(width: 64, height: 64, rect: CGRect(x: 0, y: 32, width: 64, height: 32), r: 0xF7, g: 0xF7, b: 0xF5)
        for i in stride(from: 0, to: px.count, by: 4) where lower[i + 3] == 255 { px[i] = lower[i]; px[i + 1] = lower[i + 1]; px[i + 2] = lower[i + 2]; px[i + 3] = 255 }
        let p = Palette.extract(rgba: px, k: 3)
        let names = Set(p.filter { $0.share > 0.2 }.map(\.name))
        #expect(names.contains("red"))
        #expect(names.isSuperset(of: ["red"]) && names.count >= 2)
    }

    @Test func emptyMaskGivesNothing() {
        #expect(Palette.extract(rgba: [UInt8](repeating: 0, count: 400)).isEmpty)
    }
}

@Suite struct LabelMappingTests {
    @Test func everyMappedIdentifierIsSupportedByVision() {
        let supported = Set(ClassifyImageRequest().supportedIdentifiers)
        for id in LabelMapping.table.keys { #expect(supported.contains(id), "Vision no longer knows \(id)") }
        for id in LabelMapping.genericClothing { #expect(supported.contains(id), "Vision no longer knows \(id)") }
    }

    @Test func guessTakesTheMostConfidentMappedLabel() {
        let g = LabelMapping.guess(from: [("clothing", 0.9), ("sneaker", 0.7), ("footwear", 0.8)])
        #expect(g?.category == .shoes)
        #expect(g?.label == "footwear")
        #expect(LabelMapping.looksLikeGarment([("clothing", 0.9)]) == 0.9)
        #expect(LabelMapping.guess(from: [("zebra", 0.9)]) == nil)
    }
}

@Suite struct GarmentDigitizerTests {
    @Test func compositeAndCoverage() throws {
        let img = TestImages.cgImage(width: 200, height: 100, rect: CGRect(x: 50, y: 25, width: 100, height: 50), r: 0xC4, g: 0x2B, b: 0x2B, opaqueBackground: false)
        let out = try GarmentDigitizer.composite(onWhite: img, longEdge: 100)
        #expect(out.width == 100 && out.height == 50)
        let px = Palette.rgba(from: out)!
        // corner is white, centre is red
        #expect(px[0] == 255 && px[1] == 255 && px[2] == 255)
        let c = ((25 * 100) + 50) * 4
        #expect(px[c] > 150 && px[c + 1] < 90)
        #expect(abs(GarmentDigitizer.coverage(rgba: Palette.rgba(from: img)!) - 0.25) < 0.01)
    }

    @Test func personCountOnSyntheticImageIsZero() async throws {
        let img = TestImages.cgImage(width: 256, height: 256, rect: CGRect(x: 64, y: 64, width: 128, height: 128), r: 0x2F, g: 0x5D, b: 0xA8, opaqueBackground: true)
        let n = try await GarmentDigitizer().personCount(in: img)
        #expect(n == 0)
    }

    @Test func digitizeRunsEndToEndOnASyntheticSubject() async throws {
        // Subject lifting may or may not find a flat blue square; the contract is "no throw, every result well-formed".
        let img = TestImages.cgImage(width: 512, height: 512, rect: CGRect(x: 128, y: 128, width: 256, height: 256), r: 0x2F, g: 0x5D, b: 0xA8, opaqueBackground: true)
        let garments = try await GarmentDigitizer().digitize(img)
        for g in garments {
            #expect(g.cutout.width > 0 && g.thumbnail.width <= 256)
            #expect(g.box.width > 0 && g.box.width <= 1)
            #expect(!g.palette.isEmpty)
        }
    }
}
