// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct HyperKeySettingsView: View {
    @ObservedObject private var store: SettingsStore
    @ObservedObject private var enableController: PermissionFeatureController
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    public init(
        store: SettingsStore,
        enableController: PermissionFeatureController
    ) {
        self.store = store
        self.enableController = enableController
    }

    public var body: some View {
        Form {
            Text("Use Caps Lock as Command, Control, Option, and Shift when held.")
                .font(LauncherTheme.Typography.rowSubtitle)
                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))

            Toggle("Enable Hyper Key", isOn: enabledBinding)

            if enableController.isWaiting {
                Text(PermissionFeature.hyperKey.waitingMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Tap action", selection: modeBinding) {
                Text("Do Nothing").tag(HyperKeyMode.nothing)
                Text("Escape").tag(HyperKeyMode.escape)
                Text("Toggle Caps Lock").tag(HyperKeyMode.toggle)
            }

            if let message = errorMessage ?? enableController.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(LauncherTheme.Metrics.searchHorizontalPadding)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { enableController.isEnabled },
            set: enableController.setEnabled
        )
    }

    private var modeBinding: Binding<HyperKeyMode> {
        Binding(
            get: { store.settings.hyperKey.mode },
            set: { mode in
                do {
                    try store.update { $0.hyperKey.mode = mode }
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        )
    }
}
