// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastExtensions
import XCTest

final class ExtensionPersistenceTests: XCTestCase {
    func testLocalStorageAndPreferencesRoundTrip() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ExtensionPersistence(directoryURL: directory)

        try await persistence.setLocalStorageValue(
            .object(["value": .number(42)]),
            forKey: "answer",
            extensionSlug: "sample-extension"
        )
        try await persistence.setPreferences(
            ["theme": .string("dark")],
            extensionSlug: "sample-extension"
        )

        let storage = try await persistence.localStorage(extensionSlug: "sample-extension")
        let preferences = try await persistence.preferences(extensionSlug: "sample-extension")
        XCTAssertEqual(storage["answer"], .object(["value": .number(42)]))
        XCTAssertEqual(preferences["theme"], .string("dark"))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "OmnicastExtensionsTests.\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
