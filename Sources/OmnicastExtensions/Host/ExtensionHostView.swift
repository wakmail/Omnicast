// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import WebKit

@MainActor
public struct ExtensionHostView: NSViewRepresentable {
    public typealias NSViewType = WKWebView

    private let host: ExtensionHost

    public init(host: ExtensionHost) {
        self.host = host
    }

    public func makeNSView(context: Context) -> WKWebView {
        host.makeWebView()
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {}

    public static func dismantleNSView(_ nsView: WKWebView, coordinator: ()) {
        nsView.stopLoading()
        nsView.configuration.userContentController.removeScriptMessageHandler(
            forName: "omnicast"
        )
    }
}
