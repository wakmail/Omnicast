// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct HoldToSpeakStateMachine: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case starting
        case listening
        case transcribing
    }

    public enum Event: Equatable, Sendable {
        case pressed
        case engineStarted
        case released
        case completed
        case failed
    }

    public enum Action: Equatable, Sendable {
        case startEngine
        case stopEngineAndPaste
    }

    public private(set) var phase: Phase = .idle

    public init() {}

    @discardableResult
    public mutating func handle(_ event: Event) -> Action? {
        switch (phase, event) {
        case (.idle, .pressed):
            phase = .starting
            return .startEngine
        case (.starting, .engineStarted):
            phase = .listening
        case (.starting, .released), (.listening, .released):
            phase = .transcribing
            return .stopEngineAndPaste
        case (.starting, .failed), (.listening, .failed),
             (.transcribing, .failed), (.transcribing, .completed):
            phase = .idle
        default:
            break
        }
        return nil
    }
}
