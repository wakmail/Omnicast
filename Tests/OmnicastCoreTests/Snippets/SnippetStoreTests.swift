// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

@MainActor
final class SnippetStoreTests: XCTestCase {
    func testCRUDSearchAndPersistence() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let usedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let store = try SnippetStore(directoryURL: directory)

        let first = try store.create(
            name: " Greeting ",
            keyword: " hi ",
            content: "Hello world",
            at: createdAt
        )
        let second = try store.create(
            name: "Signature",
            content: "Regards",
            at: createdAt.addingTimeInterval(1)
        )

        XCTAssertEqual(first.name, "Greeting")
        XCTAssertEqual(first.keyword, "hi")
        XCTAssertEqual(store.search("WORLD").map(\.id), [first.id])
        XCTAssertEqual(store.search("sign").map(\.id), [second.id])
        XCTAssertEqual(store.snippet(keyword: " HI ")?.id, first.id)

        let updated = try store.update(
            id: first.id,
            name: "Welcome",
            keyword: "hello",
            content: "Welcome home"
        )
        XCTAssertEqual(updated?.name, "Welcome")
        _ = try store.recordUse(id: first.id, at: usedAt)
        XCTAssertEqual(store.snippets.first?.id, first.id)

        let loaded = try SnippetStore(directoryURL: directory)
        XCTAssertEqual(loaded.snippet(id: first.id)?.lastUsed, usedAt)
        XCTAssertEqual(loaded.snippet(id: first.id)?.content, "Welcome home")
        XCTAssertTrue(try loaded.delete(id: second.id))
        XCTAssertFalse(try loaded.delete(id: second.id))
    }

    func testValidationRejectsEmptyFieldsAndQuotedKeywords() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SnippetStore(directoryURL: directory)

        XCTAssertThrowsError(try store.create(name: " ", content: "Text")) { error in
            XCTAssertEqual(error as? SnippetStoreError, .emptyName)
        }
        XCTAssertThrowsError(try store.create(name: "Name", content: " ")) { error in
            XCTAssertEqual(error as? SnippetStoreError, .emptyContent)
        }
        XCTAssertThrowsError(
            try store.create(name: "Name", keyword: "bad`key", content: "Text")
        ) { error in
            XCTAssertEqual(error as? SnippetStoreError, .invalidKeyword)
        }
    }

    func testImportsRaycastArrayAndDeduplicates() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SnippetStore(directoryURL: directory)
        _ = try store.create(name: "Existing", keyword: "old", content: "Saved")
        let data = Data(#"""
        [
            {"name":"Existing","text":"Duplicate name","keyword":"new"},
            {"name":"Duplicate keyword","text":"Duplicate","keyword":"OLD"},
            {"name":"Imported","text":"Raycast text","keyword":"rc"},
            {"name":"Bad keyword","text":"Still valid","keyword":"bad`key"},
            {"name":"","text":"Missing name"}
        ]
        """#.utf8)

        let result = try store.importRaycastJSON(data)

        XCTAssertEqual(result, SnippetImportResult(imported: 2, skipped: 2, failed: 1))
        XCTAssertEqual(store.snippet(keyword: "rc")?.content, "Raycast text")
        XCTAssertNil(store.search("Bad keyword").first?.keyword)
    }

    func testImportsFullRaycastBackupShape() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SnippetStore(directoryURL: directory)
        let data = Data(#"""
        {
            "raycast_version":"1.0",
            "builtin_package_snippets":{
                "snippets":[{"name":"Backup item","text":"From backup","keyword":"bk"}]
            }
        }
        """#.utf8)

        let result = try store.importRaycastJSON(data)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(store.snippet(keyword: "bk")?.name, "Backup item")
    }

    func testRejectsUnsupportedImportShape() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SnippetStore(directoryURL: directory)

        XCTAssertThrowsError(try store.importRaycastJSON(Data(#"{"notes":[]}"#.utf8))) { error in
            XCTAssertEqual(error as? SnippetStoreError, .invalidImport)
        }
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
