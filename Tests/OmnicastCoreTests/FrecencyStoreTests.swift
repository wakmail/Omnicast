// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

final class FrecencyStoreTests: XCTestCase {
    func testOrderingAndPersistence() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 2_000_000)

        let store = try FrecencyStore(directoryURL: directory)
        try store.recordLaunch(commandID: "alpha", query: "a", at: now)
        try store.recordLaunch(commandID: "beta", query: "b", at: now)
        try store.recordLaunch(commandID: "beta", query: "b", at: now)

        XCTAssertEqual(store.orderedCommandIDs(at: now), ["beta", "alpha"])

        let loaded = try FrecencyStore(directoryURL: directory)
        XCTAssertEqual(loaded.entries, store.entries)
    }
}
