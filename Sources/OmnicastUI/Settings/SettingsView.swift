// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var store: SettingsStore
    private let onHotkeyChange: (HotkeySettings) -> Void
    @State private var errorMessage: String?

    public init(
        store: SettingsStore,
        onHotkeyChange: @escaping (HotkeySettings) -> Void
    ) {
        self.store = store
        self.onHotkeyChange = onHotkeyChange
    }

    public var body: some View {
        Form {
            Picker("Global shortcut", selection: hotkeyBinding) {
                ForEach(HotkeySettings.presets, id: \.displayName) { hotkey in
                    Text(hotkey.displayName).tag(hotkey)
                }
            }

            Picker("Theme", selection: themeBinding) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }

            Toggle("Launch at login", isOn: launchAtLoginBinding)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, height: 240)
    }

    private var hotkeyBinding: Binding<HotkeySettings> {
        Binding(
            get: { store.settings.hotkey },
            set: { hotkey in
                perform {
                    try store.update { $0.hotkey = hotkey }
                    onHotkeyChange(hotkey)
                }
            }
        )
    }

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { store.settings.theme },
            set: { theme in
                perform { try store.update { $0.theme = theme } }
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.settings.launchAtLogin },
            set: { enabled in
                perform { try store.setLaunchAtLogin(enabled) }
            }
        )
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
