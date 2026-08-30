// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@MainActor
public protocol SpeechEngine: AnyObject {
    func speak(text: String) async throws
    func stop()
}

public enum SpeechEngineError: LocalizedError {
    case emptyText
    case noSelection
    case invalidAudio

    public var errorDescription: String? {
        switch self {
        case .emptyText:
            return "There is no text to read"
        case .noSelection:
            return "No selected text was found"
        case .invalidAudio:
            return "The speech service returned invalid audio"
        }
    }
}
