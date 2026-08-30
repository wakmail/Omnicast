// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastExtensions
import XCTest

final class ExtensionStoreTests: XCTestCase {
    func testCatalogFetchesOnceAndFiltersCachedResults() async throws {
        let client = ControlledStoreClient(bundleData: Data())
        let catalog = RaycastStoreCatalog(client: client)

        async let first = catalog.extensions()
        async let second = catalog.extensions()
        let values = try await [first, second]
        let filtered = try await catalog.search(query: "kill processes")

        XCTAssertEqual(values[0], values[1])
        XCTAssertEqual(filtered.map(\.name), ["kill-process"])
        let searchRequests = await client.searchRequestCount()
        XCTAssertEqual(searchRequests, 1)
    }

    @MainActor
    func testInstallStateMovesFromAvailableThroughProgressToInstalled() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let archiveURL = try XCTUnwrap(Bundle.module.url(
            forResource: "kill-process",
            withExtension: "tar.gz",
            subdirectory: "Fixtures"
        ))
        let client = ControlledStoreClient(bundleData: try Data(contentsOf: archiveURL))
        await client.blockDownloads()
        let registry = ExtensionRegistry(directoryURL: directory, store: client)
        let model = ExtensionStoreViewModel(
            catalog: RaycastStoreCatalog(client: client),
            registry: registry
        )

        await model.load()
        let extensionValue = try XCTUnwrap(model.extensions.first)
        XCTAssertEqual(model.state(for: extensionValue), .notInstalled)

        let installTask = Task { await model.install(extensionValue) }
        while await client.downloadRequestCount() == 0 {
            await Task.yield()
        }
        XCTAssertEqual(model.state(for: extensionValue), .installing(progress: 0.15))

        await client.releaseDownloads()
        await installTask.value
        XCTAssertEqual(model.state(for: extensionValue), .installed)

        await model.uninstall(extensionValue)
        XCTAssertEqual(model.state(for: extensionValue), .notInstalled)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ExtensionStoreTests.\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private actor ControlledStoreClient: RaycastStoreServing {
    private let bundleData: Data
    private var searchRequests = 0
    private var downloadRequests = 0
    private var shouldBlockDownloads = false
    private var downloadWaiters: [CheckedContinuation<Void, Never>] = []

    init(bundleData: Data) {
        self.bundleData = bundleData
    }

    func search(
        query: String,
        category: String?,
        limit: Int,
        offset: Int
    ) async throws -> RaycastStoreSearchResults {
        searchRequests += 1
        return RaycastStoreSearchResults(results: [Self.extensionValue], total: 1)
    }

    func metadata(for slug: String) async throws -> RaycastStoreExtension {
        Self.extensionValue
    }

    func screenshots(for slug: String) async throws -> [URL] {
        []
    }

    func downloadBundle(for slug: String) async throws -> RaycastExtensionBundle {
        downloadRequests += 1
        if shouldBlockDownloads {
            await withCheckedContinuation { continuation in
                downloadWaiters.append(continuation)
            }
        }
        return RaycastExtensionBundle(
            data: bundleData,
            sourceURL: URL(string: "https://store.example/kill-process.tar.gz")!
        )
    }

    func blockDownloads() {
        shouldBlockDownloads = true
    }

    func releaseDownloads() {
        shouldBlockDownloads = false
        let waiters = downloadWaiters
        downloadWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func searchRequestCount() -> Int {
        searchRequests
    }

    func downloadRequestCount() -> Int {
        downloadRequests
    }

    private static let extensionValue = RaycastStoreExtension(
        name: "kill-process",
        title: "Kill Process",
        description: "Find and stop processes",
        author: "rolandleth",
        commands: [
            RaycastStoreCommand(
                name: "index",
                title: "Kill Process",
                description: "Find a process"
            )
        ]
    )
}
