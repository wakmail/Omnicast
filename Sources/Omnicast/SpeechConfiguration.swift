// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore

struct AppliedSpeechConfiguration: Equatable {
    let engine: SpeechEngineChoice
    let systemVoice: String
    let systemRate: Double
    let elevenLabsVoice: String

    init(settings: AppSettings) {
        engine = settings.speechEngine
        systemVoice = settings.systemSpeechVoiceIdentifier
        systemRate = settings.systemSpeechRate
        elevenLabsVoice = settings.elevenLabsVoiceIdentifier
    }
}

@MainActor
func makeSpeechEngine(
    settings: AppSettings,
    keyStore: SpeechKeyStore
) -> any SpeechEngine {
    switch settings.speechEngine {
    case .system:
        let identifier = settings.systemSpeechVoiceIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return SystemSpeechEngine(configuration: SystemSpeechConfiguration(
            voiceIdentifier: identifier.isEmpty ? nil : identifier,
            rate: Float(settings.systemSpeechRate)
        ))
    case .elevenLabs:
        let identifier = settings.elevenLabsVoiceIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let configuration = identifier.isEmpty
            ? ElevenLabsConfiguration()
            : ElevenLabsConfiguration(voiceID: identifier)
        return ElevenLabsEngine(keyStore: keyStore, configuration: configuration)
    }
}
