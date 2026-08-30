// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

final class FileSearchIndexTests: XCTestCase {
    func testExclusionRulesCoverGeneratedAndCacheDirectories() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        XCTAssertTrue(
            FileSearchIndex.shouldExclude(
                home.appendingPathComponent("project/node_modules/package/file.js"),
                homeDirectory: home
            )
        )
        XCTAssertTrue(
            FileSearchIndex.shouldExclude(
                home.appendingPathComponent("project/.git/config"),
                homeDirectory: home
            )
        )
        XCTAssertTrue(
            FileSearchIndex.shouldExclude(
                home.appendingPathComponent("Library/Caches/example/cache.db"),
                homeDirectory: home
            )
        )
        XCTAssertFalse(
            FileSearchIndex.shouldExclude(
                home.appendingPathComponent("Documents/report.txt"),
                homeDirectory: home
            )
        )
    }

    func testFallbackWalkFindsMatchesAndSkipsExcludedTrees() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("Source", isDirectory: true)
        let dependencies = source.appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: dependencies, withIntermediateDirectories: true)
        try Data("visible".utf8).write(to: source.appendingPathComponent("Quarterly Report.txt"))
        try Data("hidden".utf8).write(to: dependencies.appendingPathComponent("Report.js"))

        let results = await FileSearchIndex.fallbackResults(
            roots: [directory],
            matching: "report",
            limit: 20
        )

        XCTAssertEqual(results.map(\.displayName), ["Quarterly Report.txt"])
        XCTAssertEqual(results.first?.kind, .file)
    }
}
