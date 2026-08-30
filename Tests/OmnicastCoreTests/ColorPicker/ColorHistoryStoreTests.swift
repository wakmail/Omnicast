// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

@MainActor
final class ColorHistoryStoreTests: XCTestCase {
    func testRoundTripAndDeduplication() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ColorHistoryStore(directoryURL: directory)

        try store.record(hex: "112233", createdAt: Date(timeIntervalSince1970: 1))
        try store.record(hex: "#AABBCC", createdAt: Date(timeIntervalSince1970: 2))
        try store.record(hex: "#112233", createdAt: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(store.items.map(\.hex), ["#112233", "#AABBCC"])
        let loaded = try ColorHistoryStore(directoryURL: directory)
        XCTAssertEqual(loaded.items, store.items)
    }

    func testClearPersists() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ColorHistoryStore(directoryURL: directory)
        try store.record(hex: "FFFFFF")

        try store.clear()

        XCTAssertTrue(try ColorHistoryStore(directoryURL: directory).items.isEmpty)
    }

    func testColorComponentMapping() {
        XCTAssertEqual(PickColorCommand.hex(red: 1, green: 0.5, blue: 0), "#FF8000")
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
