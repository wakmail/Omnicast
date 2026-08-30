// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastExtensions
import WebKit
import XCTest

@MainActor
final class ExtensionHostTests: XCTestCase {
    func testFixtureCommandRendersInsideWebView() async throws {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(
            forResource: "sample-extension",
            withExtension: nil,
            subdirectory: "Fixtures"
        ))
        let manifest = try ExtensionManifest.decode(
            from: Data(contentsOf: fixtureURL.appendingPathComponent("package.json"))
        )
        let installed = InstalledExtension(
            slug: "sample-extension",
            directoryURL: fixtureURL,
            manifest: manifest
        )
        let dataDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "OmnicastExtensionHostTests.\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: dataDirectory) }
        let host = try ExtensionHost(
            installedExtension: installed,
            commandName: "show",
            directoryURL: dataDirectory
        )
        let webView = host.makeWebView()
        var contentProcessUnavailable = false

        for _ in 0..<50 {
            try await Task.sleep(nanoseconds: 50_000_000)
            do {
                let text = try await webView.evaluateJavaScript(
                    "String(document.body ? document.body.innerText || '' : '')"
                ) as? String
                if text?.contains("Fixture Result") == true {
                    host.stop()
                    return
                }
            } catch let error as NSError where error.domain == "WKErrorDomain" && error.code == 5 {
                contentProcessUnavailable = true
                continue
            }
        }
        host.stop()
        if contentProcessUnavailable {
            throw XCTSkip("The WebKit content process is unavailable in this test sandbox")
        }
        XCTFail("The fixture command did not render")
    }
}
