// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import OmnicastCore
import OmnicastExtensions
import OmnicastUI
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(
        store: SettingsStore,
        snippetStore: SnippetStore,
        snippetExpander: SnippetExpander,
        quicklinkStore: QuicklinkStore,
        aiKeyStore: AIKeyStore,
        windowAdjuster: WindowAdjuster,
        hyperKeyManager: HyperKeyManager,
        extensionRegistry: ExtensionRegistry,
        extensionStoreClient: RaycastStoreClient,
        onRegistryChanged: @escaping () -> Void
    ) {
        let extensions = ExtensionSettingsView(
            registry: extensionRegistry,
            client: extensionStoreClient,
            onRegistryChanged: onRegistryChanged
        )
        let view = SettingsTabsView(
            store: store,
            snippetStore: snippetStore,
            snippetExpander: snippetExpander,
            quicklinkStore: quicklinkStore,
            aiKeyStore: aiKeyStore,
            windowAdjuster: windowAdjuster,
            hyperKeyManager: hyperKeyManager,
            extensionsView: AnyView(extensions)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Omnicast Settings"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
