// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine
import OmnicastCore
import OmnicastUI
import SwiftUI

@MainActor
final class DictationHUDPanelController {
    private let panel: NSPanel
    private var subscriptions = Set<AnyCancellable>()

    init(controller: HoldToSpeakController) {
        let model = DictationHUDViewModel(controller: controller)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: DictationHUDView(viewModel: model))
        self.panel = panel

        model.$state
            .removeDuplicates()
            .sink { [weak self] state in
                self?.updateVisibility(for: state)
            }
            .store(in: &subscriptions)
    }

    private func updateVisibility(for state: DictationHUDState) {
        if state == .idle {
            panel.orderOut(nil)
            return
        }
        positionPanel()
        panel.orderFrontRegardless()
    }

    private func positionPanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - panel.frame.width / 2,
            y: visible.minY + 64
        ))
    }
}
