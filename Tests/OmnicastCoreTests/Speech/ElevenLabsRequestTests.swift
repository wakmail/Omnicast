// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

@MainActor
final class ElevenLabsRequestTests: XCTestCase {
    func testStreamingRequestContainsCredentialAndConfiguration() throws {
        let engine = ElevenLabsEngine(
            keyStore: InMemorySpeechKeyStore(key: "secret"),
            configuration: ElevenLabsConfiguration(
                voiceID: "voice123",
                modelID: "eleven_flash_v2_5",
                outputFormat: "mp3_44100_128"
            ),
            audioPlayer: SilentAudioPlayer()
        )

        let request = try engine.makeRequest(text: "Read this")
        let data = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "xi-api-key"), "secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "audio/mpeg")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.elevenlabs.io/v1/text-to-speech/voice123/stream?output_format=mp3_44100_128"
        )
        XCTAssertEqual(body["text"] as? String, "Read this")
        XCTAssertEqual(body["model_id"] as? String, "eleven_flash_v2_5")
    }

    func testRequestRequiresKey() {
        let engine = ElevenLabsEngine(
            keyStore: InMemorySpeechKeyStore(),
            audioPlayer: SilentAudioPlayer()
        )

        XCTAssertThrowsError(try engine.makeRequest(text: "Read this")) { error in
            XCTAssertEqual(error as? ElevenLabsError, .missingAPIKey)
        }
    }
}

@MainActor
private final class SilentAudioPlayer: SpeechAudioPlaying {
    func play(data: Data) throws {}
    func stop() {}
}
