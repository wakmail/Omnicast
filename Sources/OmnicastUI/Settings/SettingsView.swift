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

            Picker("Window mode", selection: windowModeBinding) {
                ForEach(LauncherWindowMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            LabeledContent("Pop to root") {
                TextField("Seconds", value: popToRootTimeoutBinding, format: .number)
                    .frame(width: 80)
                Text("seconds")
                    .foregroundStyle(.secondary)
            }
            Text("Set this to 0 to keep the current view until you leave it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Navigation style", selection: navigationStyleBinding) {
                ForEach(LauncherNavigationStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            Text("macOS style is visual only for now.")
                .font(.caption)
                .foregroundStyle(.secondary)

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

    private var windowModeBinding: Binding<LauncherWindowMode> {
        Binding(
            get: { store.settings.windowMode },
            set: { mode in
                perform { try store.update { $0.windowMode = mode } }
            }
        )
    }

    private var popToRootTimeoutBinding: Binding<Double> {
        Binding(
            get: { store.settings.popToRootTimeout },
            set: { seconds in
                perform { try store.update { $0.popToRootTimeout = max(0, seconds) } }
            }
        )
    }

    private var navigationStyleBinding: Binding<LauncherNavigationStyle> {
        Binding(
            get: { store.settings.navigationStyle },
            set: { style in
                perform { try store.update { $0.navigationStyle = style } }
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
