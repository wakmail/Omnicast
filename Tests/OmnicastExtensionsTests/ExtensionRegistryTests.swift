// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastExtensions
import XCTest

final class ExtensionRegistryTests: XCTestCase {
    func testInstallListAndUninstallFixtureBundle() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bundle = try makeFixtureBundle(in: directory)
        let registry = ExtensionRegistry(
            directoryURL: directory,
            store: FixtureStore(bundle: bundle)
        )

        let installed = try await registry.install(storeSlug: "sample-extension")
        XCTAssertEqual(installed.manifest.title, "Sample Extension")
        XCTAssertEqual(installed.commands.map(\.manifest.name), ["show"])
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: installed.commands[0].bundleURL.path
        ))

        let listed = try await registry.listInstalled()
        XCTAssertEqual(listed.map(\.slug), ["sample-extension"])

        try await registry.uninstall(slug: "sample-extension")
        let afterUninstall = try await registry.listInstalled()
        XCTAssertTrue(afterUninstall.isEmpty)
    }

    private func makeFixtureBundle(in directory: URL) throws -> Data {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(
            forResource: "sample-extension",
            withExtension: nil,
            subdirectory: "Fixtures"
        ))
        let archiveURL = directory.appendingPathComponent("fixture.tar.gz")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = [
            "-czf",
            archiveURL.path,
            "-C",
            fixtureURL.deletingLastPathComponent().path,
            fixtureURL.lastPathComponent
        ]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        return try Data(contentsOf: archiveURL)
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

private struct FixtureStore: RaycastStoreServing {
    let bundle: Data

    func search(
        query: String,
        category: String?,
        limit: Int,
        offset: Int
    ) async throws -> RaycastStoreSearchResults {
        RaycastStoreSearchResults(results: [], total: 0)
    }

    func metadata(for slug: String) async throws -> RaycastStoreExtension {
        RaycastStoreExtension(
            name: slug,
            title: "Sample Extension",
            description: "Fixture",
            author: "omnicast"
        )
    }

    func downloadBundle(for slug: String) async throws -> RaycastExtensionBundle {
        RaycastExtensionBundle(
            data: bundle,
            sourceURL: URL(string: "https://example.com/fixture.tar.gz")!
        )
    }
}
