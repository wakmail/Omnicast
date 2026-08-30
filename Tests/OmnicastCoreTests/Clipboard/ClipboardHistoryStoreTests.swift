// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

@MainActor
final class ClipboardHistoryStoreTests: XCTestCase {
    func testPersistsTextFilesAndSourceApplication() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = ClipboardSourceApplication(
            bundleIdentifier: "com.example.Editor",
            name: "Editor"
        )
        let fileURL = directory.appendingPathComponent("Document.txt")

        let store = try ClipboardHistoryStore(directoryURL: directory)
        let textItem = try store.recordText(
            "  First line\r\nSecond line  ",
            sourceApplication: source,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let fileItem = try store.recordFiles(
            [fileURL],
            sourceApplication: source,
            createdAt: Date(timeIntervalSince1970: 2)
        )

        let loaded = try ClipboardHistoryStore(directoryURL: directory)
        XCTAssertEqual(loaded.items.count, 2)
        XCTAssertEqual(loaded.items.first?.id, fileItem.id)
        XCTAssertEqual(loaded.items.last?.id, textItem.id)
        XCTAssertEqual(loaded.items.last?.textContent, "First line\nSecond line")
        XCTAssertEqual(loaded.items.last?.sourceApplication, source)
        XCTAssertEqual(loaded.items.first?.fileURLs, [fileURL])
    }

    func testDedupesOnlyConsecutiveIdenticalText() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardHistoryStore(directoryURL: directory)

        let first = try store.recordText("Repeated", createdAt: Date(timeIntervalSince1970: 1))
        let duplicate = try store.recordText(" Repeated\n", createdAt: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(first.id, duplicate.id)
        XCTAssertEqual(store.items.count, 1)

        try store.recordText("Different", createdAt: Date(timeIntervalSince1970: 3))
        let later = try store.recordText("Repeated", createdAt: Date(timeIntervalSince1970: 4))
        XCTAssertNotEqual(later.id, first.id)
        XCTAssertEqual(store.items.count, 3)
    }

    func testPinnedItemsSurviveUnpinnedLimit() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clipboardDirectory = directory.appendingPathComponent("Clipboard", isDirectory: true)
        try FileManager.default.createDirectory(at: clipboardDirectory, withIntermediateDirectories: true)

        let pinned = ClipboardItem(
            kind: .text,
            previewText: "Pinned",
            textContent: "Pinned",
            createdAt: Date(timeIntervalSince1970: 0),
            isPinned: true
        )
        let unpinned = (0...ClipboardHistoryStore.maximumUnpinnedItemCount).map { index in
            ClipboardItem(
                kind: .text,
                previewText: "Item \(index)",
                textContent: "Item \(index)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index + 1))
            )
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode([pinned] + unpinned)
        try data.write(to: clipboardDirectory.appendingPathComponent("history.json"))

        let store = try ClipboardHistoryStore(directoryURL: directory)
        XCTAssertEqual(store.items.filter(\.isPinned).map(\.id), [pinned.id])
        XCTAssertEqual(store.items.filter { !$0.isPinned }.count, 500)
        XCTAssertFalse(store.items.contains { $0.previewText == "Item 0" })
    }

    func testImageDataLivesOutsideJSONAndIsRemovedOnDelete() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardHistoryStore(directoryURL: directory)
        let pngData = Data([0x89, 0x50, 0x4E, 0x47])

        let item = try store.recordImage(
            pngData: pngData,
            pixelWidth: 10,
            pixelHeight: 20
        )
        let imagePath = try XCTUnwrap(item.imageFilePath)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: imagePath)), pngData)

        let indexData = try Data(contentsOf: store.indexFileURL)
        let indexJSON = String(decoding: indexData, as: UTF8.self)
        XCTAssertLessThan(indexData.count, 2_000)
        XCTAssertFalse(indexJSON.contains(pngData.base64EncodedString()))
        XCTAssertFalse(indexJSON.contains("imageData"))

        XCTAssertTrue(try store.delete(id: item.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: imagePath))
    }

    func testSearchUsesPreviewText() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardHistoryStore(directoryURL: directory)
        let longText = String(repeating: "a", count: ClipboardTextContent.previewLength) + "hidden"
        try store.recordText(longText)
        try store.recordText("Résumé notes")

        XCTAssertEqual(store.search("resume").count, 1)
        XCTAssertTrue(store.search("hidden").isEmpty)
        XCTAssertEqual(store.search("  ").count, 2)
    }

    func testTogglePinAndClearPersist() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardHistoryStore(directoryURL: directory)
        let item = try store.recordText("Keep this")

        XCTAssertEqual(try store.togglePin(id: item.id)?.isPinned, true)
        XCTAssertEqual(try ClipboardHistoryStore(directoryURL: directory).items.first?.isPinned, true)

        try store.clear()
        XCTAssertTrue(try ClipboardHistoryStore(directoryURL: directory).items.isEmpty)
    }

    func testContentLimitsRejectOversizedValues() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardHistoryStore(directoryURL: directory)

        XCTAssertThrowsError(
            try store.recordText(String(repeating: "x", count: ClipboardTextContent.maximumLength + 1))
        ) { error in
            XCTAssertEqual(error as? ClipboardHistoryError, .textTooLarge)
        }
        XCTAssertThrowsError(
            try store.recordImage(
                pngData: dataWithCount(ClipboardHistoryStore.maximumImageByteCount + 1)
            )
        ) { error in
            XCTAssertEqual(error as? ClipboardHistoryError, .imageTooLarge)
        }
        XCTAssertTrue(store.items.isEmpty)
    }

    private func dataWithCount(_ count: Int) -> Data {
        Data(count: count)
    }
}
