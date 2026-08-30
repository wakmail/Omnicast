// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testRoundTrip() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SettingsStore(directoryURL: directory)
        try store.update { settings in
            settings.hotkey = .controlSpace
            settings.theme = .dark
            settings.launchAtLogin = true
        }

        let loaded = try SettingsStore(directoryURL: directory)
        XCTAssertEqual(loaded.settings, store.settings)
    }
}
