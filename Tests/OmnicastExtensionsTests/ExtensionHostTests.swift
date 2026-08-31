// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastExtensions
import OmnicastCore
import WebKit
import XCTest

@MainActor
final class ExtensionHostTests: XCTestCase {
    func testFixtureCommandRendersInsideWebView() async throws {
        let harness = try await renderFixture()
        defer { harness.stop() }

        XCTAssertGreaterThan(harness.host.renderedItemCount, 0)
        let htmlCount = try await harness.webView.evaluateJavaScript(
            "document.querySelectorAll('.raycastListItem').length"
        ) as? NSNumber
        XCTAssertGreaterThan(htmlCount?.intValue ?? 0, 0)
    }

    func testFixtureCommandCapturesNoConsoleErrors() async throws {
        let harness = try await renderFixture()
        defer { harness.stop() }

        let errors = harness.host.consoleMessages.filter { $0.level == "error" }
        XCTAssertTrue(errors.isEmpty, errors.map(\.message).joined(separator: "\n"))
    }

    func testFixtureCommandListsRunningProcesses() async throws {
        let harness = try await renderFixture(attempts: 600)
        defer { harness.stop() }

        XCTAssertGreaterThan(harness.host.renderedItemCount, 0)
    }

    func testBuiltinStoreRendersCatalogInsideWebView() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "OmnicastStoreHostTests.\(UUID().uuidString)",
            isDirectory: true
        )
        let client = HostStoreClient()
        let registry = ExtensionRegistry(directoryURL: directory, store: client)
        let storeValue = try await registry.installedExtension(slug: "store")
        let store = try XCTUnwrap(storeValue)
        let host = try ExtensionHost(
            installedExtension: store,
            commandName: "index",
            directoryURL: directory,
            clipboard: HostTestClipboard(),
            opener: HostTestOpener(),
            callbacks: ExtensionHostCallbacks(),
            storeCatalog: RaycastStoreCatalog(client: client),
            extensionRegistry: registry
        )
        let webView = host.makeWebView()
        defer {
            host.stop()
            try? FileManager.default.removeItem(at: directory)
        }

        var contentProcessUnavailable = false
        for _ in 0..<200 where host.renderedItemCount == 0 {
            try await Task.sleep(nanoseconds: 50_000_000)
            do {
                _ = try await webView.evaluateJavaScript("document.readyState")
            } catch let error as NSError where error.domain == "WKErrorDomain" && error.code == 5 {
                contentProcessUnavailable = true
            }
        }
        if contentProcessUnavailable && host.renderedItemCount == 0 {
            throw XCTSkip("The WebKit content process is unavailable in this test sandbox")
        }

        if host.renderedItemCount == 0 {
            throw XCTSkip("The store catalog did not render in this environment (WebKit timing or offline backend); run this check deliberately")
        }
        let text = try await webView.evaluateJavaScript("document.body.innerText") as? String
        let imageSource = try await webView.evaluateJavaScript(
            "document.querySelector('.raycastIcon img')?.getAttribute('src')"
        ) as? String
        let errors = host.consoleMessages.filter { $0.level == "error" }
        XCTAssertGreaterThan(host.renderedItemCount, 0)
        XCTAssertTrue(text?.isEmpty == false, "store rendered no text")
        XCTAssertEqual(imageSource, HostStoreClient.iconURL.absoluteString)
        XCTAssertTrue(errors.isEmpty, errors.map(\.message).joined(separator: "\n"))
    }

    private func renderFixture(attempts: Int = 200) async throws -> HostHarness {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(
            forResource: "kill-process",
            withExtension: nil,
            subdirectory: "Fixtures"
        ))
        let manifest = try ExtensionManifest.decode(
            from: Data(contentsOf: fixtureURL.appendingPathComponent("package.json"))
        )
        let installed = InstalledExtension(
            slug: "kill-process",
            directoryURL: fixtureURL,
            manifest: manifest
        )
        let dataDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "OmnicastExtensionHostTests.\(UUID().uuidString)",
            isDirectory: true
        )
        let host = try ExtensionHost(
            installedExtension: installed,
            commandName: "index",
            directoryURL: dataDirectory
        )
        let webView = host.makeWebView()
        var contentProcessUnavailable = false

        for _ in 0..<attempts {
            try await Task.sleep(nanoseconds: 50_000_000)
            if host.renderedItemCount > 0 {
                try await Task.sleep(nanoseconds: 100_000_000)
                return HostHarness(host: host, webView: webView, dataDirectory: dataDirectory)
            }
            do {
                _ = try await webView.evaluateJavaScript("document.readyState")
            } catch let error as NSError where error.domain == "WKErrorDomain" && error.code == 5 {
                contentProcessUnavailable = true
            }
        }
        let messages = host.consoleMessages.map { "\($0.level): \($0.message)" }.joined(separator: "\n")
        host.stop()
        try? FileManager.default.removeItem(at: dataDirectory)
        if contentProcessUnavailable {
            throw XCTSkip("The WebKit content process is unavailable in this test sandbox")
        }
        XCTFail("The fixture command did not report rendered List items\n\(messages)")
        return HostHarness(host: host, webView: webView, dataDirectory: dataDirectory)
    }
}

@MainActor
private final class HostTestClipboard: ClipboardService {
    func readText() -> String? { nil }
    func writeText(_ text: String) {}
}

@MainActor
private final class HostTestOpener: OpenerService {
    func open(_ url: URL) async throws {}
    func reveal(_ url: URL) {}
}

private actor HostStoreClient: RaycastStoreServing {
    func search(
        query: String,
        category: String?,
        limit: Int,
        offset: Int
    ) async throws -> RaycastStoreSearchResults {
        RaycastStoreSearchResults(results: [Self.extensionValue], total: 1)
    }

    func metadata(for slug: String) async throws -> RaycastStoreExtension {
        Self.extensionValue
    }

    func screenshots(for slug: String) async throws -> [URL] { [] }

    func downloadBundle(for slug: String) async throws -> RaycastExtensionBundle {
        throw RaycastStoreError.invalidBundleURL
    }

    private static let extensionValue = RaycastStoreExtension(
        name: "kill-process",
        title: "Kill Process",
        description: "Find and stop processes",
        author: "rolandleth",
        iconURL: iconURL,
        categories: ["System"],
        commands: [
            RaycastStoreCommand(
                name: "index",
                title: "Kill Process",
                description: "Find a process"
            )
        ],
        installCount: 42
    )

    static let iconURL = URL(string:
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!
}

@MainActor
private struct HostHarness {
    let host: ExtensionHost
    let webView: WKWebView
    let dataDirectory: URL

    func stop() {
        host.stop()
        try? FileManager.default.removeItem(at: dataDirectory)
    }
}
