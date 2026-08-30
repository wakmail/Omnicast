// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension RaycastImporter {
    static func decodeHotkey(_ value: String) -> RaycastImportedCommandHotkey? {
        let parts = value.split(separator: "-").map(String.init).filter { !$0.isEmpty }
        guard let rawCode = parts.last,
              let keyCode = UInt32(rawCode),
              let keyName = keyNames[keyCode] else {
            return nil
        }
        var modifiers: UInt32 = 0
        var names: [String] = []
        for rawModifier in parts.dropLast() {
            switch rawModifier.lowercased() {
            case "command", "cmd": modifiers |= 256; names.append("Command")
            case "shift": modifiers |= 512; names.append("Shift")
            case "option", "alt": modifiers |= 2_048; names.append("Option")
            case "control", "ctrl": modifiers |= 4_096; names.append("Control")
            case "fn", "function": names.append("Function")
            default: continue
            }
        }
        names.append(keyName)
        return RaycastImportedCommandHotkey(
            keyCode: keyCode,
            modifiers: modifiers,
            displayName: names.joined(separator: " ")
        )
    }

    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "Equals", 25: "9", 26: "7", 27: "Minus", 28: "8", 29: "0",
        30: "Right Bracket", 31: "O", 32: "U", 33: "Left Bracket", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "Quote", 40: "K", 41: "Semicolon", 42: "Backslash", 43: "Comma", 44: "Slash",
        45: "N", 46: "M", 47: "Period", 48: "Tab", 49: "Space", 50: "Grave", 51: "Backspace",
        53: "Escape", 71: "Clear", 76: "Enter", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12",
        113: "F15", 114: "Insert", 115: "Home", 116: "Page Up", 117: "Delete", 118: "F4", 119: "End",
        120: "F2", 121: "Page Down", 122: "F1", 123: "Left", 124: "Right", 125: "Down", 126: "Up"
    ]
}
