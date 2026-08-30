// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import OmnicastUI

@MainActor
final class LauncherPanel: NSPanel {
    let keyEvents: LauncherKeyEvents
    private var previousApplication: NSRunningApplication?

    init(keyEvents: LauncherKeyEvents) {
        self.keyEvents = keyEvents
        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: LauncherTheme.Metrics.panelWidth,
                height: LauncherTheme.Metrics.panelHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func showNearTop() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != currentPID {
            previousApplication = frontmost
        }

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.midX - frame.width / 2,
                y: visible.maxY - frame.height - min(90, visible.height * 0.12)
            )
            setFrameOrigin(origin)
        }

        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }

    func hide(returningFocus: Bool) {
        orderOut(nil)
        if returningFocus {
            previousApplication?.activate()
        }
    }

    override func resignKey() {
        super.resignKey()
        guard isVisible else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible, self.childWindows?.isEmpty != false else { return }
            self.hide(returningFocus: false)
        }
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown else {
            super.sendEvent(event)
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command), event.keyCode == 40 {
            keyEvents.send(.actions)
            return
        }
        if modifiers.contains(.command), event.keyCode == 43 {
            keyEvents.send(.settings)
            return
        }

        switch event.keyCode {
        case 126:
            keyEvents.send(.moveUp)
        case 125:
            keyEvents.send(.moveDown)
        case 36, 76:
            keyEvents.send(.enter)
        case 53:
            keyEvents.send(.escape)
        default:
            super.sendEvent(event)
        }
    }
}
