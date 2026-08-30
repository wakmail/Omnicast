// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@MainActor
public final class SpeechCoordinator {
    public let engine: any SpeechEngine

    public init(engine: any SpeechEngine) {
        self.engine = engine
    }

    public func speak(_ text: String) async throws {
        engine.stop()
        try await engine.speak(text: text)
    }

    public func stop() {
        engine.stop()
    }
}

public struct ReadSelectionCommand: Command {
    public let id = "system.read-selection"
    public let title = "Read Selection"
    public let subtitle = "Read selected text aloud"
    public let icon = CommandIcon.sfSymbol("speaker.wave.2.fill")
    public let keywords = ["speak", "speech", "selection", "voice"]
    public let kind = CommandKind.system

    private let coordinator: SpeechCoordinator
    private let selectionReader: any SelectedTextReading

    @MainActor
    public init(
        coordinator: SpeechCoordinator,
        selectionReader: (any SelectedTextReading)? = nil
    ) {
        self.coordinator = coordinator
        self.selectionReader = selectionReader ?? FrontmostSelectedTextReader()
    }

    @MainActor
    public func execute(context: CommandContext) async throws {
        guard let text = await selectionReader.selectedText(), !text.isEmpty else {
            throw SpeechEngineError.noSelection
        }
        try await coordinator.speak(text)
        context.toasts.show("Reading selected text")
    }
}

public struct StopSpeechCommand: Command {
    public let id = "system.stop-speech"
    public let title = "Stop Reading"
    public let subtitle = "Stop reading text aloud"
    public let icon = CommandIcon.sfSymbol("speaker.slash.fill")
    public let keywords = ["stop", "speech", "voice"]
    public let kind = CommandKind.system

    private let coordinator: SpeechCoordinator

    public init(coordinator: SpeechCoordinator) {
        self.coordinator = coordinator
    }

    @MainActor
    public func execute(context: CommandContext) async throws {
        coordinator.stop()
        context.toasts.show("Stopped reading")
    }
}

public struct SpeechCommandsProvider: CommandProvider {
    private let values: [any Command]

    @MainActor
    public init(
        engine: any SpeechEngine,
        selectionReader: (any SelectedTextReading)? = nil
    ) {
        let coordinator = SpeechCoordinator(engine: engine)
        let reader = selectionReader ?? FrontmostSelectedTextReader()
        values = [
            ReadSelectionCommand(
                coordinator: coordinator,
                selectionReader: reader
            ),
            StopSpeechCommand(coordinator: coordinator)
        ]
    }

    public func commands() async -> [any Command] {
        values
    }
}
