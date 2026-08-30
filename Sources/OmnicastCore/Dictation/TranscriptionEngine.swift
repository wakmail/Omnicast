// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@MainActor
public protocol TranscriptionEngine: AnyObject {
    func start() -> AsyncThrowingStream<String, Error>
    func stop() async throws -> String
}

@MainActor
public protocol AudioLevelReporting: AnyObject {
    var onAudioLevel: ((Double) -> Void)? { get set }
}

public enum TranscriptionEngineError: LocalizedError {
    case alreadyRunning
    case microphonePermissionRequired
    case speechPermissionRequired
    case recognizerUnavailable(String)
    case audioInputUnavailable
    case audioEngine(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Transcription is already running"
        case .microphonePermissionRequired:
            return "Microphone permission is required"
        case .speechPermissionRequired:
            return "Speech recognition permission is required"
        case .recognizerUnavailable(let language):
            return "Speech recognition is unavailable for \(language)"
        case .audioInputUnavailable:
            return "Audio input is unavailable"
        case .audioEngine(let message):
            return "The audio engine could not start: \(message)"
        }
    }
}
