// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct SettingsTabsView: View {
    private let store: SettingsStore
    private let snippetStore: SnippetStore
    private let quicklinkStore: QuicklinkStore
    private let aiKeyStore: AIKeyStore
    private let permissions: PermissionsService
    private let snippetEnableController: PermissionFeatureController
    private let hyperKeyEnableController: PermissionFeatureController
    private let extensionsView: AnyView

    @MainActor
    public init(
        store: SettingsStore,
        snippetStore: SnippetStore,
        quicklinkStore: QuicklinkStore,
        aiKeyStore: AIKeyStore,
        permissions: PermissionsService,
        snippetEnableController: PermissionFeatureController,
        hyperKeyEnableController: PermissionFeatureController,
        extensionsView: AnyView
    ) {
        self.store = store
        self.snippetStore = snippetStore
        self.quicklinkStore = quicklinkStore
        self.aiKeyStore = aiKeyStore
        self.permissions = permissions
        self.snippetEnableController = snippetEnableController
        self.hyperKeyEnableController = hyperKeyEnableController
        self.extensionsView = extensionsView
    }

    public var body: some View {
        TabView {
            SettingsView(
                store: store,
                onHotkeyChange: { _ in }
            )
            .tabItem { Label("General", systemImage: "gear") }

            HyperKeySettingsView(
                store: store,
                enableController: hyperKeyEnableController
            )
                .tabItem { Label("Hyper Key", systemImage: "capslock") }

            SnippetSettingsView(
                snippetStore: snippetStore,
                enableController: snippetEnableController
            )
                .tabItem { Label("Snippets", systemImage: "text.quote") }

            PermissionsView(permissions: permissions)
                .tabItem { Label("Permissions", systemImage: "hand.raised") }

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
