// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var store: SettingsStore
    private let onHotkeyChange: (HotkeySettings) -> Void
    private let onHotkeyRecordingChanged: (Bool) -> Void
    @State private var errorMessage: String?

    public init(
        store: SettingsStore,
        onHotkeyChange: @escaping (HotkeySettings) -> Void,
        onHotkeyRecordingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.store = store
        self.onHotkeyChange = onHotkeyChange
        self.onHotkeyRecordingChanged = onHotkeyRecordingChanged
    }

    public var body: some View {
        Form {
            ShortcutRecorderView(
                shortcut: hotkeyBinding,
                onRecordingChanged: onHotkeyRecordingChanged
            )

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
        .padding(LauncherTheme.Metrics.searchHorizontalPadding)
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
