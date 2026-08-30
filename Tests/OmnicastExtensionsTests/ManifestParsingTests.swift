// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastExtensions
import XCTest

final class ManifestParsingTests: XCTestCase {
    func testParsesGitLabStoreManifestShape() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "gitlab-package",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        let manifest = try ExtensionManifest.decode(from: Data(contentsOf: url))

        XCTAssertEqual(manifest.name, "gitlab")
        XCTAssertEqual(manifest.author?.name, "tonka3000")
        XCTAssertEqual(manifest.platforms, ["macOS", "Windows"])
        XCTAssertEqual(manifest.commands.map(\.name), ["search-projects", "search-issues"])
        XCTAssertEqual(manifest.preferences.count, 2)
        XCTAssertEqual(manifest.preferences[0].defaultValue, .string("detail"))
        XCTAssertEqual(manifest.preferences[1].defaultValue, .bool(false))
        XCTAssertEqual(manifest.commands[1].arguments.first?.name, "query")
    }
}
