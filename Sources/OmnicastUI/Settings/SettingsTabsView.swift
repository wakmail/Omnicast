// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct SettingsTabsView: View {
    private let store: SettingsStore
    private let snippetStore: SnippetStore
    private let snippetExpander: SnippetExpander
    private let quicklinkStore: QuicklinkStore
    private let aiKeyStore: AIKeyStore
    private let windowAdjuster: WindowAdjuster
    private let hyperKeyManager: HyperKeyManager
    private let extensionsView: AnyView

    @MainActor
    public init(
        store: SettingsStore,
        snippetStore: SnippetStore,
        snippetExpander: SnippetExpander,
        quicklinkStore: QuicklinkStore,
        aiKeyStore: AIKeyStore,
        windowAdjuster: WindowAdjuster,
        hyperKeyManager: HyperKeyManager,
        extensionsView: AnyView
    ) {
        self.store = store
        self.snippetStore = snippetStore
        self.snippetExpander = snippetExpander
        self.quicklinkStore = quicklinkStore
        self.aiKeyStore = aiKeyStore
        self.windowAdjuster = windowAdjuster
        self.hyperKeyManager = hyperKeyManager
        self.extensionsView = extensionsView
    }

    public var body: some View {
        TabView {
            SettingsView(
                store: store,
                onHotkeyChange: { _ in },
                windowAdjuster: windowAdjuster,
                hyperKeyManager: hyperKeyManager,
                snippetExpander: snippetExpander
            )
            .tabItem { Label("General", systemImage: "gear") }

            HyperKeySettingsView(store: store, manager: hyperKeyManager)
                .tabItem { Label("Hyper Key", systemImage: "capslock") }

            SnippetManagerView(store: snippetStore)
                .tabItem { Label("Snippets", systemImage: "text.quote") }

            QuicklinkManagerView(store: quicklinkStore)
                .tabItem { Label("Quick Links", systemImage: "link") }

            AISettingsView(store: store, keyStore: aiKeyStore)
                .tabItem { Label("AI", systemImage: "sparkles") }

            extensionsView
                .tabItem { Label("Extensions", systemImage: "puzzlepiece.extension") }
        }
        .tint(LauncherTheme.Palette.accent)
        .frame(minWidth: 820, minHeight: 560)
    }
}
