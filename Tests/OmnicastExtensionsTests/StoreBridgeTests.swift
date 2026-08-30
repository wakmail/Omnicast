// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import OmnicastExtensions
import XCTest

@MainActor
final class StoreBridgeTests: XCTestCase {
    func testThirdPartySlugCannotCallStoreBridge() async throws {
        let harness = try makeHarness(slug: "third-party")
        defer { harness.remove() }

        let response = await harness.router.route(ExtensionBridgeRequest(
            id: "catalog",
            operation: .storeCatalog
        ))

        XCTAssertNil(response.result)
        XCTAssertEqual(
            response.error,
            "The Store bridge is available only to the builtin Store extension"
        )
        let searchCount = await harness.client.searchRequestCount()
        XCTAssertEqual(searchCount, 0)
    }

    func testBuiltinStoreCanReadCatalogAndInstalledExtensions() async throws {
        let harness = try makeHarness(slug: "store")
        defer { harness.remove() }

        let catalog = await harness.router.route(ExtensionBridgeRequest(
            id: "catalog",
            operation: .storeCatalog
        ))
        let installed = await harness.router.route(ExtensionBridgeRequest(
            id: "installed",
            operation: .storeInstalled
        ))

        guard case .array(let catalogValues) = catalog.result,
              case .object(let first) = catalogValues.first else {
            return XCTFail("The catalog bridge returned an unexpected value")
        }
        XCTAssertEqual(first["name"], .string("kill-process"))
        XCTAssertEqual(first["author"], .string("rolandleth"))
        XCTAssertEqual(first["installCount"], .number(42))
        XCTAssertEqual(installed.result, .array([.string("store")]))
        XCTAssertNil(catalog.error)
        XCTAssertNil(installed.error)
        let searchCount = await harness.client.searchRequestCount()
        XCTAssertEqual(searchCount, 1)
    }

    func testBuiltinStoreInstallsThroughInjectedRegistry() async throws {
        let harness = try makeHarness(slug: "store")
        defer { harness.remove() }

        let response = await harness.router.route(ExtensionBridgeRequest(
            id: "install",
            operation: .storeInstall,
            payload: ["name": .string("kill-process")]
        ))

        XCTAssertNil(response.error)
        XCTAssertEqual(
            response.result,
            .object([
                "name": .string("kill-process"),
                "title": .string("Kill Process")
            ])
        )
        let installed = try await harness.registry.installedExtension(slug: "kill-process")
        let downloadCount = await harness.client.downloadRequestCount()
        XCTAssertNotNil(installed)
        XCTAssertEqual(downloadCount, 1)
        XCTAssertEqual(harness.changes.count, 1)
    }

    private func makeHarness(slug: String) throws -> StoreBridgeHarness {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "StoreBridgeTests.\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let archiveURL = try XCTUnwrap(Bundle.module.url(
            forResource: "kill-process",
            withExtension: "tar.gz",
            subdirectory: "Fixtures"
        ))
        let client = BridgeStoreClient(bundleData: try Data(contentsOf: archiveURL))
        let registry = ExtensionRegistry(directoryURL: directory, store: client)
        let changes = RegistryChangeRecorder()
        let router = ExtensionBridgeRouter(
            extensionSlug: slug,
            persistence: ExtensionPersistence(directoryURL: directory),
            clipboard: StoreBridgeClipboard(),
            opener: StoreBridgeOpener(),
            callbacks: ExtensionHostCallbacks(
                extensionRegistryChanged: { changes.count += 1 }
            ),
            storeCatalog: RaycastStoreCatalog(client: client),
            extensionRegistry: registry
        )
        return StoreBridgeHarness(
            directory: directory,
            router: router,
            registry: registry,
            client: client,
            changes: changes
        )
    }
}

@MainActor
private struct StoreBridgeHarness {
    let directory: URL
    let router: ExtensionBridgeRouter
    let registry: ExtensionRegistry
    let client: BridgeStoreClient
    let changes: RegistryChangeRecorder

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
private final class RegistryChangeRecorder {
    var count = 0
}

@MainActor
private final class StoreBridgeClipboard: ClipboardService {
    func readText() -> String? { nil }
    func writeText(_ text: String) {}
}

@MainActor
private final class StoreBridgeOpener: OpenerService {
    func open(_ url: URL) async throws {}
    func reveal(_ url: URL) {}
}

private actor BridgeStoreClient: RaycastStoreServing {
    private let bundleData: Data
    private var searchRequests = 0
    private var downloadRequests = 0

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

    func screenshots(for slug: String) async throws -> [URL] { [] }

    func downloadBundle(for slug: String) async throws -> RaycastExtensionBundle {
        downloadRequests += 1
        return RaycastExtensionBundle(
            data: bundleData,
            sourceURL: URL(string: "https://store.example/kill-process.tar.gz")!
        )
    }

    func searchRequestCount() -> Int { searchRequests }
    func downloadRequestCount() -> Int { downloadRequests }

    private static let extensionValue = RaycastStoreExtension(
        name: "kill-process",
        title: "Kill Process",
        description: "Find and stop processes",
        author: "rolandleth",
        iconURL: URL(string: "https://store.example/icon.png"),
        categories: ["System"],
        platforms: ["macOS"],
        commands: [
            RaycastStoreCommand(
                name: "index",
                title: "Kill Process",
                description: "Find a process"
            )
        ],
        installCount: 42
    )
}
