// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation

public struct SystemSpeechConfiguration: Equatable, Sendable {
    public var voiceIdentifier: String?
    public var language: String?
    public var rate: Float

    public init(
        voiceIdentifier: String? = nil,
        language: String? = nil,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate
    ) {
        self.voiceIdentifier = voiceIdentifier
        self.language = language
        self.rate = rate
    }
}

@MainActor
public final class SystemSpeechEngine: SpeechEngine {
    public var configuration: SystemSpeechConfiguration

    private let synthesizer: AVSpeechSynthesizer

    public init(
        configuration: SystemSpeechConfiguration = SystemSpeechConfiguration(),
        synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()
    ) {
        self.configuration = configuration
        self.synthesizer = synthesizer
    }

    public func speak(text: String) async throws {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw SpeechEngineError.emptyText }
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = min(
            AVSpeechUtteranceMaximumSpeechRate,
            max(AVSpeechUtteranceMinimumSpeechRate, configuration.rate)
        )
        if let identifier = configuration.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else if let language = configuration.language {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        }
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
