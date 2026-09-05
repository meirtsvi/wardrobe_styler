// shared/rules/color_palette.json (PLAN §5.4). Colour maths for the on-device provisional swatch lands with the Vision module.
import Foundation

public struct ColorPalette: Decodable, Sendable {
    public let version: Int
    public let named: [String: String]
    public let neutrals: [String]
    public let seasonal: [String: [String]]

    public static let shared: ColorPalette = SharedResources.decode("color_palette")
}
