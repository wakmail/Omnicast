// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastExtensions
import XCTest

final class ExtensionRegistryTests: XCTestCase {
    func testInstallListAndUninstallFixtureBundle() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let archiveURL = try XCTUnwrap(Bundle.module.url(
            forResource: "kill-process",
            withExtension: "tar.gz",
            subdirectory: "Fixtures"
        ))
        let registry = ExtensionRegistry(directoryURL: directory)

        let installed = try await registry.install(fromArchive: archiveURL)
        XCTAssertEqual(installed.manifest.title, "Kill Process")
        XCTAssertEqual(installed.commands.map(\.manifest.name), ["index"])
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: installed.commands[0].bundleURL.path
        ))

        let listed = try await registry.listInstalled()
        XCTAssertEqual(listed.map(\.slug), ["kill-process"])

        try await registry.uninstall(slug: "kill-process")
        let afterUninstall = try await registry.listInstalled()
        XCTAssertTrue(afterUninstall.isEmpty)
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
