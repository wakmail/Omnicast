// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct HyperKeySettingsView: View {
    @ObservedObject private var store: SettingsStore
    private let manager: HyperKeyManager
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    @MainActor
    public init(store: SettingsStore, manager: HyperKeyManager) {
        self.store = store
        self.manager = manager
    }

    public var body: some View {
        Form {
            Text("Use Caps Lock as Command, Control, Option, and Shift when held.")
                .font(LauncherTheme.Typography.rowSubtitle)
                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))

            Toggle("Enable Hyper Key", isOn: enabledBinding)

            Picker("Tap action", selection: modeBinding) {
                Text("Do Nothing").tag(HyperKeyMode.nothing)
                Text("Escape").tag(HyperKeyMode.escape)
                Text("Toggle Caps Lock").tag(HyperKeyMode.toggle)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LauncherTheme.Typography.footerTitle)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding(LauncherTheme.Metrics.searchHorizontalPadding)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { store.settings.hyperKey.enabled },
            set: { enabled in update { $0.enabled = enabled } }
        )
    }

    private var modeBinding: Binding<HyperKeyMode> {
        Binding(
            get: { store.settings.hyperKey.mode },
            set: { mode in update { $0.mode = mode } }
        )
    }

    private func update(_ change: (inout HyperKeySettings) -> Void) {
        do {
            try store.update { change(&$0.hyperKey) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
