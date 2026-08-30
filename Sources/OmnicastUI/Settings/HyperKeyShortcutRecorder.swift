// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

struct HyperKeyShortcutRecorder: NSViewRepresentable {
    let keyCode: UInt16
    let modifiers: UInt64
    let onChange: (UInt16, UInt64) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton(title: "", target: context.coordinator, action: #selector(Coordinator.record))
        button.bezelStyle = .rounded
        button.keyHandler = context.coordinator.handle
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.keyCode = keyCode
        context.coordinator.modifiers = modifiers
        if !context.coordinator.isRecording {
            button.title = ShortcutDisplay.name(keyCode: keyCode, modifiers: modifiers)
        }
    }

    final class Coordinator: NSObject {
        weak var button: ShortcutRecorderButton?
        var onChange: (UInt16, UInt64) -> Void
        var keyCode: UInt16 = 49
        var modifiers: UInt64 = 0
        var isRecording = false

        init(onChange: @escaping (UInt16, UInt64) -> Void) {
            self.onChange = onChange
        }

        @objc func record() {
            isRecording = true
            button?.title = "Press a shortcut"
            button?.window?.makeFirstResponder(button)
        }

        func handle(_ event: NSEvent) {
            if event.keyCode == 53 {
                finishRecording()
                return
            }
            let allowed: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
            let capturedModifiers = event.modifierFlags.intersection(allowed).rawValue
            onChange(event.keyCode, UInt64(capturedModifiers))
            keyCode = event.keyCode
            modifiers = UInt64(capturedModifiers)
            finishRecording()
        }

        private func finishRecording() {
            isRecording = false
            button?.title = ShortcutDisplay.name(keyCode: keyCode, modifiers: modifiers)
            button?.window?.makeFirstResponder(nil)
        }
    }
}

final class ShortcutRecorderButton: NSButton {
    var keyHandler: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        keyHandler?(event)
    }
}

private enum ShortcutDisplay {
    static func name(keyCode: UInt16, modifiers: UInt64) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        var name = ""
        if flags.contains(.control) { name += "⌃" }
        if flags.contains(.option) { name += "⌥" }
        if flags.contains(.shift) { name += "⇧" }
        if flags.contains(.command) { name += "⌘" }
        if flags.contains(.function) { name += "fn " }
        return name + keyNames[keyCode, default: "Key \(keyCode)"]
    }

    private static let keyNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "−", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
        50: "`", 51: "Delete", 53: "Escape", 65: ".", 67: "*", 69: "+",
        71: "Clear", 75: "/", 76: "Enter", 78: "−", 81: "=", 82: "0",
        83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7",
        91: "8", 92: "9", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
        100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F16", 107: "F14",
        109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home",
        116: "Page Up", 117: "Forward Delete", 118: "F4", 119: "End", 120: "F2",
        121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}
