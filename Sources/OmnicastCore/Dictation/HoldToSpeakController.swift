// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

@MainActor
public final class HoldToSpeakController: ObservableObject {
    @Published public private(set) var phase: HoldToSpeakStateMachine.Phase = .idle

    public var onPartialTranscript: ((String) -> Void)?
    public var onAudioLevel: ((Double) -> Void)?
    public var onError: ((Error) -> Void)?

    private let engine: any TranscriptionEngine
    private let pasteService: RestoringPasteService
    private let hotkeyMonitor: HoldHotkeyMonitor
    private var stateMachine = HoldToSpeakStateMachine()
    private var transcriptTask: Task<Void, Never>?

    public init(
        engine: any TranscriptionEngine,
        pasteService: RestoringPasteService? = nil,
        hotkey: HoldHotkeyMonitor.Configuration = .function
    ) {
        self.engine = engine
        self.pasteService = pasteService ?? RestoringPasteService()
        self.hotkeyMonitor = HoldHotkeyMonitor(configuration: hotkey)
        hotkeyMonitor.onPressed = { [weak self] in self?.press() }
        hotkeyMonitor.onReleased = { [weak self] in self?.release() }
        if let levelEngine = engine as? any AudioLevelReporting {
            levelEngine.onAudioLevel = { [weak self] level in
                self?.onAudioLevel?(level)
            }
        }
    }

    public func startMonitoring() throws {
        try hotkeyMonitor.start()
    }

    public func stopMonitoring() {
        hotkeyMonitor.stop()
    }

    public func press() {
        guard stateMachine.handle(.pressed) == .startEngine else { return }
        publishPhase()
        let stream = engine.start()
        stateMachine.handle(.engineStarted)
        publishPhase()
        transcriptTask = Task { @MainActor [weak self] in
            do {
                for try await transcript in stream {
                    guard !Task.isCancelled else { return }
                    self?.onPartialTranscript?(transcript)
                }
            } catch is CancellationError {
                return
            } catch {
                self?.fail(error)
            }
        }
    }

    public func release() {
        guard stateMachine.handle(.released) == .stopEngineAndPaste else { return }
        publishPhase()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let finalText = try await engine.stop()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !finalText.isEmpty {
                    try await pasteService.paste(finalText)
                }
                transcriptTask?.cancel()
                stateMachine.handle(.completed)
                publishPhase()
            } catch {
                fail(error)
            }
        }
    }

    private func fail(_ error: Error) {
        transcriptTask?.cancel()
        stateMachine.handle(.failed)
        publishPhase()
        onError?(error)
    }

    private func publishPhase() {
        phase = stateMachine.phase
    }
}
