// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation

public struct ElevenLabsConfiguration: Equatable, Sendable {
    public var voiceID: String
    public var modelID: String
    public var outputFormat: String

    public init(
        voiceID: String = "21m00Tcm4TlvDq8ikWAM",
        modelID: String = "eleven_multilingual_v2",
        outputFormat: String = "mp3_44100_128"
    ) {
        self.voiceID = voiceID
        self.modelID = modelID
        self.outputFormat = outputFormat
    }
}

@MainActor
public protocol SpeechAudioPlaying: AnyObject {
    func play(data: Data) throws
    func stop()
}

@MainActor
public final class SystemSpeechAudioPlayer: NSObject, SpeechAudioPlaying {
    private var player: AVAudioPlayer?

    public override init() {}

    public func play(data: Data) throws {
        let player = try AVAudioPlayer(data: data)
        player.prepareToPlay()
        guard player.play() else { throw SpeechEngineError.invalidAudio }
        self.player = player
    }

    public func stop() {
        player?.stop()
        player = nil
    }

}

@MainActor
public final class ElevenLabsEngine: SpeechEngine {
    public var configuration: ElevenLabsConfiguration

    private let keyStore: any SpeechKeyStoring
    private let session: URLSession
    private let audioPlayer: any SpeechAudioPlaying
    private let baseURL: URL
    private var downloadTask: Task<Data, Error>?
    private var downloadID: UUID?

    public init(
        keyStore: any SpeechKeyStoring,
        configuration: ElevenLabsConfiguration = ElevenLabsConfiguration(),
        session: URLSession = .shared,
        audioPlayer: (any SpeechAudioPlaying)? = nil,
        baseURL: URL = URL(string: "https://api.elevenlabs.io")!
    ) {
        self.keyStore = keyStore
        self.configuration = configuration
        self.session = session
        self.audioPlayer = audioPlayer ?? SystemSpeechAudioPlayer()
        self.baseURL = baseURL
    }

    public func makeRequest(text: String) throws -> URLRequest {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw SpeechEngineError.emptyText }
        guard let key = try keyStore.elevenLabsAPIKey(), !key.isEmpty else {
            throw ElevenLabsError.missingAPIKey
        }

        let endpoint = baseURL
            .appending(path: "v1")
            .appending(path: "text-to-speech")
            .appending(path: configuration.voiceID)
            .appending(path: "stream")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw ElevenLabsError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "output_format", value: configuration.outputFormat)
        ]
        guard let url = components.url else { throw ElevenLabsError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(text: text, modelID: configuration.modelID)
        )
        return request
    }

    public func speak(text: String) async throws {
        stop()
        let request = try makeRequest(text: text)
        let identifier = UUID()
        downloadID = identifier
        let task = Task.detached { [session] in
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw ElevenLabsError.invalidResponse
            }
            guard (200..<400).contains(response.statusCode) else {
                var body = Data()
                for try await byte in bytes {
                    if body.count == 500 { break }
                    body.append(byte)
                }
                throw ElevenLabsError.httpStatus(
                    response.statusCode,
                    String(decoding: body, as: UTF8.self)
                )
            }
            var audio = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                audio.append(byte)
            }
            guard !audio.isEmpty else { throw ElevenLabsError.emptyAudio }
            return audio
        }
        downloadTask = task
        do {
            let audio = try await task.value
            guard downloadID == identifier else { return }
            downloadTask = nil
            downloadID = nil
            try audioPlayer.play(data: audio)
        } catch {
            if downloadID == identifier {
                downloadTask = nil
                downloadID = nil
            }
            throw error
        }
    }

    public func stop() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadID = nil
        audioPlayer.stop()
    }
}

private struct RequestBody: Encodable {
    let text: String
    let modelID: String

    enum CodingKeys: String, CodingKey {
        case text
        case modelID = "model_id"
    }
}

public enum ElevenLabsError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String)
    case emptyAudio

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No ElevenLabs API key is configured"
        case .invalidURL:
            return "The ElevenLabs URL is invalid"
        case .invalidResponse:
            return "ElevenLabs returned an invalid response"
        case .httpStatus(let status, let body):
            return "ElevenLabs returned HTTP \(status): \(body)"
        case .emptyAudio:
            return "ElevenLabs returned no audio"
        }
    }
}
