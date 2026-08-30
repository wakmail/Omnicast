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

            Picker("Tap action", selection: actionKindBinding) {
                ForEach(HyperKeyTapActionKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }

            switch store.settings.hyperKey.tapAction {
            case .keyboardShortcut(let keyCode, let modifiers):
                LabeledContent("Shortcut") {
                    HyperKeyShortcutRecorder(
                        keyCode: keyCode,
                        modifiers: modifiers,
                        onChange: updateShortcut
                    )
                    .frame(width: 180)
                }
            case .openApplication(let bundleIdentifier):
                HyperKeyApplicationPicker(
                    bundleIdentifier: Binding(
                        get: { bundleIdentifier },
                        set: updateApplication
                    )
                )
            default:
                EmptyView()
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

    private var actionKindBinding: Binding<HyperKeyTapActionKind> {
        Binding(
            get: { HyperKeyTapActionKind(store.settings.hyperKey.tapAction) },
            set: { kind in updateAction(kind.defaultAction) }
        )
    }

    private func updateShortcut(keyCode: UInt16, modifiers: UInt64) {
        updateAction(.keyboardShortcut(keyCode: keyCode, modifiers: modifiers))
    }

    private func updateApplication(_ bundleIdentifier: String) {
        updateAction(.openApplication(bundleIdentifier: bundleIdentifier))
    }

    private func updateAction(_ action: HyperKeyTapAction) {
        do {
            try store.update { $0.hyperKey.tapAction = action }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum HyperKeyTapActionKind: String, CaseIterable, Identifiable {
    case none
    case escape
    case openOmnicast
    case keyboardShortcut
    case openApplication
    case toggleCapsLock

    init(_ action: HyperKeyTapAction) {
        switch action {
        case .none: self = .none
        case .escape: self = .escape
        case .openOmnicast: self = .openOmnicast
        case .keyboardShortcut: self = .keyboardShortcut
        case .openApplication: self = .openApplication
        case .toggleCapsLock: self = .toggleCapsLock
        }
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .escape: "Escape"
        case .openOmnicast: "Open Omnicast"
        case .keyboardShortcut: "Keyboard Shortcut"
        case .openApplication: "Open an App"
        case .toggleCapsLock: "Natural Caps Lock"
        }
    }

    var defaultAction: HyperKeyTapAction {
        switch self {
        case .none: .none
        case .escape: .escape
        case .openOmnicast: .openOmnicast
        case .keyboardShortcut:
            .keyboardShortcut(keyCode: 49, modifiers: 1 << 20)
        case .openApplication:
            .openApplication(bundleIdentifier: "")
        case .toggleCapsLock:
            .toggleCapsLock
        }
    }
}
