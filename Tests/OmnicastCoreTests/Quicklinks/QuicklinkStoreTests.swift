// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

@MainActor
final class QuicklinkStoreTests: XCTestCase {
    func testCRUDAndPersistence() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let createdAt = Date(timeIntervalSince1970: 10)
        let updatedAt = Date(timeIntervalSince1970: 20)
        let store = try QuicklinkStore(directoryURL: directory)

        let created = try store.create(
            name: "  GitHub  ",
            urlTemplate: "https://github.com/search?q={query}",
            openWithAppBundleIdentifier: "com.apple.Safari",
            icon: "Search",
            now: createdAt
        )
        XCTAssertEqual(created.name, "GitHub")
        XCTAssertTrue(created.requiresArgument)

        let updated = try store.update(
            id: created.id,
            name: "GitHub Code",
            urlTemplate: "https://github.com/search?type=code&q={query}",
            icon: "Globe",
            now: updatedAt
        )
        XCTAssertEqual(updated.updatedAt, updatedAt)

        let loaded = try QuicklinkStore(directoryURL: directory)
        XCTAssertEqual(loaded.quicklinks, store.quicklinks)
        try loaded.delete(id: created.id)
        XCTAssertTrue(loaded.quicklinks.isEmpty)
        XCTAssertTrue(try QuicklinkStore(directoryURL: directory).quicklinks.isEmpty)
    }

    func testImportsRaycastExportAndConvertsArgumentPlaceholder() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try QuicklinkStore(directoryURL: directory)
        let data = Data(
            """
            {
              "builtin_package_quicklinks": {
                "quicklinks": [
                  {"uuid":"B42B54D8-FA80-4A45-B875-83F97DBBC608","name":"Search","url":"https://example.com/?q={argument}"},
                  {"name":"Search","url":"https://example.com/?q={argument}"},
                  {"name":"Broken"}
                ]
              }
            }
            """.utf8
        )

        let result = try store.importRaycastExport(data: data)

        XCTAssertEqual(result, QuicklinkImportResult(found: 3, imported: 1, skipped: 1, failed: 1))
        XCTAssertEqual(store.quicklinks.first?.urlTemplate, "https://example.com/?q={query}")
        XCTAssertEqual(store.quicklinks.first?.icon, "Search")
    }

    func testResolvesEncodedQuery() throws {
        let quicklink = Quicklink(
            name: "Search",
            urlTemplate: "https://example.com/?q={query}"
        )
        XCTAssertEqual(
            try quicklink.resolvedURL(query: "Swift C++").absoluteString,
            "https://example.com/?q=Swift%20C%2B%2B"
        )
        XCTAssertThrowsError(try quicklink.resolvedURL()) { error in
            XCTAssertEqual(error as? QuicklinkError, .missingQuery)
        }
    }

    func testProviderCreatesOneCommandPerStoredQuicklink() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try QuicklinkStore(directoryURL: directory)
        let quicklink = try store.create(
            name: "Docs",
            urlTemplate: "https://example.com/docs",
            icon: "Globe"
        )

        let commands = await QuicklinkCommandsProvider(directoryURL: directory).commands()

        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.id, "quicklink-\(quicklink.id.uuidString.lowercased())")
        XCTAssertEqual(commands.first?.kind, .quicklink)
    }
}
