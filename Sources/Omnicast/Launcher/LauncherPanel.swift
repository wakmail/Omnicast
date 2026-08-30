// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import OmnicastCore
import OmnicastUI

@MainActor
final class LauncherPanel: NSPanel {
    let keyEvents: LauncherKeyEvents
    var onPositionChanged: ((LauncherWindowPosition) -> Void)?
    private var previousApplication: NSRunningApplication?
    private weak var previousKeyWindow: NSWindow?
    private var positioningProgrammatically = false
    private var positionSaveWorkItem: DispatchWorkItem?

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
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func showNearTop(position: LauncherWindowPosition?) {
        if let keyWindow = NSApp.keyWindow, keyWindow !== self, keyWindow.isVisible {
            previousKeyWindow = keyWindow
        } else {
            previousKeyWindow = nil
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != currentPID {
            previousApplication = frontmost
        }

        positioningProgrammatically = true
        if let position, isPositionVisible(position) {
            setFrameOrigin(NSPoint(x: position.x, y: position.y))
        } else {
            setDefaultPosition()
        }
        positioningProgrammatically = false

        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }

    func resetPosition() {
        positioningProgrammatically = true
        setDefaultPosition()
        positioningProgrammatically = false
    }

    override func setFrameOrigin(_ point: NSPoint) {
        super.setFrameOrigin(point)
        if isVisible, !positioningProgrammatically {
            positionSaveWorkItem?.cancel()
            let position = LauncherWindowPosition(x: Double(point.x), y: Double(point.y))
            let work = DispatchWorkItem { [weak self] in
                self?.onPositionChanged?(position)
            }
            positionSaveWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }

    func hide(returningFocus: Bool) {
        orderOut(nil)
        if returningFocus {
            if let previousKeyWindow, previousKeyWindow.isVisible {
                NSApp.activate(ignoringOtherApps: true)
                previousKeyWindow.makeKeyAndOrderFront(nil)
            } else {
                previousApplication?.activate()
            }
        }
        previousKeyWindow = nil
        previousApplication = nil
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
        if modifiers.contains(.command), (event.keyCode == 36 || event.keyCode == 76) {
            keyEvents.send(.commandEnter)
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

    private func setDefaultPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        setFrameOrigin(NSPoint(
            x: visible.midX - frame.width / 2,
            y: visible.maxY - frame.height - min(90, visible.height * 0.12)
        ))
    }

    private func isPositionVisible(_ position: LauncherWindowPosition) -> Bool {
        let proposed = NSRect(
            x: position.x,
            y: position.y,
            width: frame.width,
            height: frame.height
        )
        return NSScreen.screens.contains { $0.visibleFrame.intersects(proposed) }
    }
}
