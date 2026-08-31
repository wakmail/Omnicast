// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

final class IconDiskCacheTests: XCTestCase {
    func testStoresAndReadsData() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = IconDiskCache(directoryURL: directory)
        let url = try XCTUnwrap(URL(string: "https://example.com/icon.png"))
        let expected = Data([1, 2, 3, 4])

        try await cache.store(expected, for: url)

        let actual = await cache.data(for: url)
        XCTAssertEqual(actual, expected)
    }

    func testEvictsOldestFileWhenCountLimitIsExceeded() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = IconDiskCache(
            directoryURL: directory,
            maximumFileCount: 2,
            maximumByteCount: 1_024
        )
        let first = try XCTUnwrap(URL(string: "https://example.com/first.png"))
        let second = try XCTUnwrap(URL(string: "https://example.com/second.png"))
        let third = try XCTUnwrap(URL(string: "https://example.com/third.png"))

        try await cache.store(Data([1]), for: first)
        try await cache.store(Data([2]), for: second)
        try setModificationDate(.distantPast, for: first, in: directory)
        try setModificationDate(.now, for: second, in: directory)
        try await cache.store(Data([3]), for: third)

        let firstData = await cache.data(for: first)
        let secondData = await cache.data(for: second)
        let thirdData = await cache.data(for: third)
        XCTAssertNil(firstData)
        XCTAssertEqual(secondData, Data([2]))
        XCTAssertEqual(thirdData, Data([3]))
    }

    func testEvictsOldestFileWhenByteLimitIsExceeded() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = IconDiskCache(
            directoryURL: directory,
            maximumFileCount: 10,
            maximumByteCount: 4
        )
        let first = try XCTUnwrap(URL(string: "https://example.com/large.png"))
        let second = try XCTUnwrap(URL(string: "https://example.com/new.png"))

        try await cache.store(Data([1, 2, 3]), for: first)
        try setModificationDate(.distantPast, for: first, in: directory)
        try await cache.store(Data([4, 5, 6]), for: second)

        let firstData = await cache.data(for: first)
        let secondData = await cache.data(for: second)
        XCTAssertNil(firstData)
        XCTAssertEqual(secondData, Data([4, 5, 6]))
    }

    func testCacheKeyIsStableAndURLSpecific() throws {
        let first = try XCTUnwrap(URL(string: "https://example.com/icon.png"))
        let second = try XCTUnwrap(URL(string: "https://example.com/other.png"))

        XCTAssertEqual(
            IconDiskCache.cacheKey(for: first),
            IconDiskCache.cacheKey(for: first)
        )
        XCTAssertNotEqual(
            IconDiskCache.cacheKey(for: first),
            IconDiskCache.cacheKey(for: second)
        )
        XCTAssertEqual(IconDiskCache.cacheKey(for: first).count, 64)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "IconDiskCacheTests.\(UUID().uuidString)",
            isDirectory: true
        )
    }

    private func setModificationDate(
        _ date: Date,
        for url: URL,
        in directory: URL
    ) throws {
        let fileURL = directory.appendingPathComponent(
            IconDiskCache.cacheKey(for: url)
        )
        try FileManager.default.setAttributes(
            [.modificationDate: date],
            ofItemAtPath: fileURL.path
        )
    }
}
