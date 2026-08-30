// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore

@MainActor
public final class DictationHUDViewModel: ObservableObject {
    @Published public private(set) var state: DictationHUDState = .idle
    @Published public private(set) var partialTranscript = ""

    private let controller: HoldToSpeakController
    private var cancellables: Set<AnyCancellable> = []

    public init(controller: HoldToSpeakController) {
        self.controller = controller
        controller.$phase
            .sink { [weak self] phase in
                self?.apply(phase)
            }
            .store(in: &cancellables)
        controller.onAudioLevel = { [weak self] level in
            guard case .listening = self?.state else { return }
            self?.state = .listening(normalizing: level)
        }
        controller.onPartialTranscript = { [weak self] transcript in
            self?.partialTranscript = transcript
        }
    }

    private func apply(_ phase: HoldToSpeakStateMachine.Phase) {
        switch phase {
        case .idle:
            state = .idle
            partialTranscript = ""
        case .starting, .listening:
            state = .listening(level: 0)
        case .transcribing:
            state = .transcribing
        }
    }
}
