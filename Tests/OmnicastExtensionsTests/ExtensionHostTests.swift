// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastExtensions
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

    private func renderFixture() async throws -> HostHarness {
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

        for _ in 0..<200 {
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
private struct HostHarness {
    let host: ExtensionHost
    let webView: WKWebView
    let dataDirectory: URL

    func stop() {
        host.stop()
        try? FileManager.default.removeItem(at: dataDirectory)
    }
}
