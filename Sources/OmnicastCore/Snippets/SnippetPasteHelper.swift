// SPDX-License-Identifier: GPL-3.0-or-later

import ApplicationServices
import Foundation

public enum SnippetPasteError: LocalizedError {
    case eventCreationFailed

    public var errorDescription: String? {
        "Omnicast could not create a keyboard event"
    }
}

@MainActor
public enum SnippetPasteHelper {
    public static func paste(cursorOffsetFromEnd: Int = 0) async throws {
        try postKey(keyCode: 9, flags: .maskCommand)
        if cursorOffsetFromEnd > 0 {
            try await Task.sleep(nanoseconds: 50_000_000)
            for _ in 0..<cursorOffsetFromEnd {
                try postKey(keyCode: 123)
            }
        }
    }

    static func replaceTypedText(
        backspaceCount: Int,
        cursorOffsetFromEnd: Int
    ) async throws {
        for _ in 0..<backspaceCount {
            try postKey(keyCode: 51)
        }
        try await paste(cursorOffsetFromEnd: cursorOffsetFromEnd)
    }

    private static func postKey(
        keyCode: CGKeyCode,
        flags: CGEventFlags = []
    ) throws {
        guard
            let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            throw SnippetPasteError.eventCreationFailed
        }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: SnippetPasteEvent.syntheticEventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: SnippetPasteEvent.syntheticEventMarker)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

enum SnippetPasteEvent {
    static let syntheticEventMarker: Int64 = 0x4F4D4E49
}
