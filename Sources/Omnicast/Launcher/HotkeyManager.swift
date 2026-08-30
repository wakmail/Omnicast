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
        if let hotkeyReference {
            UnregisterEventHotKey(hotkeyReference)
            self.hotkeyReference = nil
        }

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
