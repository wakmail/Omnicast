// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct SnippetSettingsView: View {
    private let snippetStore: SnippetStore
    @ObservedObject private var enableController: PermissionFeatureController

    @MainActor
    public init(
        snippetStore: SnippetStore,
        enableController: PermissionFeatureController
    ) {
        self.snippetStore = snippetStore
        self.enableController = enableController
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Toggle("Enable snippet expansion", isOn: enabledBinding)
                if enableController.isWaiting {
                    Text(PermissionFeature.snippets.waitingMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Saved snippets remain available even when automatic expansion is off.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage = enableController.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            SnippetManagerView(store: snippetStore)
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { enableController.isEnabled },
            set: enableController.setEnabled
        )
    }
}
