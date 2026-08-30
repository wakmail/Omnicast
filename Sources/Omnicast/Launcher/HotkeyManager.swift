// SPDX-License-Identifier: GPL-3.0-or-later

import Carbon
import Foundation
import OmnicastCore

enum HotkeyError: LocalizedError {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            "Could not register the global shortcut with status \(status)"
        }
    }
}

@MainActor
final class HotkeyManager {
    private var hotkeyReference: EventHotKeyRef?
    private var handlerReference: EventHandlerRef?
    private let action: () -> Void
    private(set) var isShortcutCaptureActive = false

    init(action: @escaping () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(context).takeUnretainedValue()
                Task { @MainActor in manager.action() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerReference
        )
    }

    func register(_ hotkey: HotkeySettings) throws {
        unregister()

        let identifier = EventHotKeyID(
            signature: fourCharacterCode("OMNI"),
            id: 1
        )
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotkeyReference
        )
        guard status == noErr else {
            throw HotkeyError.registrationFailed(status)
        }
    }

    func unregister() {
        if let hotkeyReference {
            UnregisterEventHotKey(hotkeyReference)
            self.hotkeyReference = nil
        }
    }

    func setShortcutCaptureActive(
        _ active: Bool,
        restoring hotkey: HotkeySettings
    ) throws {
        guard isShortcutCaptureActive != active else { return }
        isShortcutCaptureActive = active
        if active {
            unregister()
        } else {
            try register(hotkey)
        }
    }

    private func fourCharacterCode(_ value: String) -> FourCharCode {
        value.utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }

    deinit {
        if let hotkeyReference {
            UnregisterEventHotKey(hotkeyReference)
        }
        if let handlerReference {
            RemoveEventHandler(handlerReference)
        }
    }
}
