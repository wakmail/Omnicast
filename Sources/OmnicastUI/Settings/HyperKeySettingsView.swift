// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
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
            Text("Use one key as Command, Control, Option, and Shift when held.")
                .font(LauncherTheme.Typography.rowSubtitle)
                .foregroundStyle(LauncherTheme.Palette.secondaryText(for: colorScheme))

            Toggle("Enable Hyper Key", isOn: enabledBinding)

            Picker("Source key", selection: sourceKeyBinding) {
                ForEach(HyperKeySourceKey.allCases, id: \.self) { sourceKey in
                    Text(sourceKey.displayName).tag(sourceKey)
                }
            }

            Text("Caps Lock is the classic choice.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if karabinerDetected {
                Text("Karabiner is also installed or running, and using two key remappers can cause conflicts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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

    private var sourceKeyBinding: Binding<HyperKeySourceKey> {
        Binding(
            get: { store.settings.hyperKey.sourceKey },
            set: updateSourceKey
        )
    }

    private var karabinerDetected: Bool {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/karabiner/karabiner.json")
        let processDetected = NSWorkspace.shared.runningApplications.contains { application in
            application.bundleIdentifier?.localizedCaseInsensitiveContains("karabiner") == true
                || application.localizedName?.localizedCaseInsensitiveContains("karabiner") == true
        }
        return processDetected || FileManager.default.fileExists(atPath: configURL.path)
    }

    private func updateShortcut(keyCode: UInt16, modifiers: UInt64) {
        updateAction(.keyboardShortcut(keyCode: keyCode, modifiers: modifiers))
    }

    private func updateApplication(_ bundleIdentifier: String) {
        updateAction(.openApplication(bundleIdentifier: bundleIdentifier))
    }

    private func updateSourceKey(_ sourceKey: HyperKeySourceKey) {
        do {
            try store.update { $0.hyperKey.sourceKey = sourceKey }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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

private extension HyperKeySourceKey {
    var displayName: String {
        switch self {
        case .capsLock: "Caps Lock"
        case .rightCommand: "Right Command"
        case .rightOption: "Right Option"
        case .rightControl: "Right Control"
        case .fn: "Fn"
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
