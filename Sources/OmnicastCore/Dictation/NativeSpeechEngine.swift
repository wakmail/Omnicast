// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation
import Speech

@MainActor
public final class NativeSpeechEngine: TranscriptionEngine, AudioLevelReporting {
    public var onAudioLevel: ((Double) -> Void)?

    private let locale: Locale
    private let audioEngine: AVAudioEngine
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var streamContinuation: AsyncThrowingStream<String, Error>.Continuation?
    private var finalContinuation: CheckedContinuation<String, Never>?
    private var finalText = ""
    private var isRunning = false
    private var hasInstalledTap = false
    private var sessionID: UUID?

    public init(
        locale: Locale = Locale(identifier: "en-US"),
        audioEngine: AVAudioEngine = AVAudioEngine()
    ) {
        self.locale = locale
        self.audioEngine = audioEngine
    }

    public func start() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard !isRunning else {
                continuation.finish(throwing: TranscriptionEngineError.alreadyRunning)
                return
            }
            guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
                continuation.finish(throwing: TranscriptionEngineError.microphonePermissionRequired)
                return
            }
            guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
                continuation.finish(throwing: TranscriptionEngineError.speechPermissionRequired)
                return
            }
            guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
                continuation.finish(
                    throwing: TranscriptionEngineError.recognizerUnavailable(locale.identifier)
                )
                return
            }

            self.recognizer = recognizer
            self.streamContinuation = continuation
            self.finalText = ""
            self.isRunning = true
            self.sessionID = UUID()

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    self?.handleRecognition(result: result, error: error)
                }
            }

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                finish(throwing: TranscriptionEngineError.audioInputUnavailable)
                return
            }
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                request.append(buffer)
                let level = Self.normalizedLevel(buffer)
                Task { @MainActor in
                    self?.onAudioLevel?(level)
                }
            }
            hasInstalledTap = true

            audioEngine.prepare()
            do {
                try audioEngine.start()
            } catch {
                finish(throwing: TranscriptionEngineError.audioEngine(error.localizedDescription))
            }

            continuation.onTermination = { [weak self] reason in
                guard case .cancelled = reason else { return }
                Task { @MainActor in
                    self?.cancel()
                }
            }
        }
    }

    public func stop() async throws -> String {
        guard isRunning else { return finalText }
        let identifier = sessionID
        stopAudioInput()
        request?.endAudio()

        return await withCheckedContinuation { continuation in
            finalContinuation = continuation
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard self?.sessionID == identifier,
                      self?.finalContinuation != nil else { return }
                self?.completeFinalization()
            }
        }
    }

    public func cancel() {
        finalContinuation?.resume(returning: finalText)
        finalContinuation = nil
        finish(throwing: CancellationError())
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            finalText = result.bestTranscription.formattedString
            streamContinuation?.yield(finalText)
            if result.isFinal {
                completeFinalization()
                return
            }
        }

        if let error {
            let code = (error as NSError).code
            if code == 203 || code == 216 {
                if finalContinuation != nil {
                    completeFinalization()
                }
                return
            }
            finish(throwing: error)
        }
    }

    private func completeFinalization() {
        let text = finalText
        finalContinuation?.resume(returning: text)
        finalContinuation = nil
        finish()
    }

    private func finish(throwing error: Error? = nil) {
        stopAudioInput()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        recognizer = nil
        isRunning = false
        sessionID = nil
        if let error {
            streamContinuation?.finish(throwing: error)
        } else {
            streamContinuation?.finish()
        }
        streamContinuation = nil
    }

    private func stopAudioInput() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
    }

    nonisolated private static func normalizedLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }
        let rootMeanSquare = sqrt(sum / Float(count))
        let decibels = 20 * log10(max(rootMeanSquare, 0.000_001))
        return min(1, max(0, Double((decibels + 60) / 60)))
    }
}
