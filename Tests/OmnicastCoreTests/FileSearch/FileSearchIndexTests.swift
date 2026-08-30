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

    func testProtectedFolderScanReportsOnlyAccessDeniedRoots() async {
        let downloads = URL(fileURLWithPath: "/Users/example/Downloads", isDirectory: true)
        let desktop = URL(fileURLWithPath: "/Users/example/Desktop", isDirectory: true)
        let documents = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)
        let fileManager = StubFileSearchManager(
            contents: [desktop: [], documents: []],
            errors: [
                downloads: NSError(
                    domain: NSCocoaErrorDomain,
                    code: CocoaError.Code.fileReadNoPermission.rawValue
                ),
                documents: NSError(domain: NSCocoaErrorDomain, code: CocoaError.Code.fileNoSuchFile.rawValue)
            ]
        )

        let scan = await FileSearchIndex.fallbackScan(
            roots: [downloads, desktop, documents],
            matching: "report",
            fileManager: fileManager
        )

        XCTAssertEqual(scan.results, [])
        XCTAssertEqual(scan.deniedRoots, [downloads])
        XCTAssertEqual(fileManager.requestedRoots, Set([downloads, desktop, documents]))
    }
}

private final class StubFileSearchManager: FileSearchFileManaging {
    private let contents: [URL: [URL]]
    private let errors: [URL: NSError]
    private let lock = NSLock()
    private var requested = Set<URL>()

    init(contents: [URL: [URL]], errors: [URL: NSError]) {
        self.contents = contents
        self.errors = errors
    }

    var requestedRoots: Set<URL> {
        lock.withLock { requested }
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        lock.withLock { _ = requested.insert(url) }
        if let error = errors[url] {
            throw error
        }
        return contents[url] ?? []
    }
}
