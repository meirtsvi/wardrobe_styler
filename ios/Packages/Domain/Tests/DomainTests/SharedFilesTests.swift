import Foundation
import Testing
@testable import Domain

/// The package resources are copies of ../../shared (see scripts/sync-shared.sh). This test fails when they drift.
@Suite struct SharedFilesTests {
    static let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent() // DomainTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // Domain
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // ios
        .deletingLastPathComponent() // repo

    @Test(arguments: [("temperature.json", "shared/rules/temperature.json"),
                      ("taxonomy.json", "shared/schemas/taxonomy.json"),
                      ("color_palette.json", "shared/rules/color_palette.json")])
    func resourceMatchesShared(resource: String, sharedPath: String) throws {
        let bundled = try Data(contentsOf: try #require(Bundle.module.url(forResource: resource, withExtension: nil)))
        let shared = try Data(contentsOf: Self.repoRoot.appendingPathComponent(sharedPath))
        #expect(bundled == shared, "\(resource) differs from \(sharedPath); run scripts/sync-shared.sh")
    }
}
