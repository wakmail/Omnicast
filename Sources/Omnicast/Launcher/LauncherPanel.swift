// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import OmnicastCore
import OmnicastUI

@MainActor
final class LauncherPanel: NSPanel {
    let keyEvents: LauncherKeyEvents
    var onPositionChanged: ((LauncherWindowPosition?) -> Void)?
    private var previousApplication: NSRunningApplication?
    private weak var previousKeyWindow: NSWindow?
    private var positioningProgrammatically = false
    private var isDraggingPanel = false
    private var localMouseUpMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private let snapGuide = LauncherPanelSnapGuideWindow()

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillMove(_:)),
            name: NSWindow.willMoveNotification,
            object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        MainActor.assumeIsolated {
            removeMouseUpMonitors()
        }
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
        cancelDrag()
        positioningProgrammatically = true
        setDefaultPosition()
        positioningProgrammatically = false
    }

    func hide(returningFocus: Bool) {
        cancelDrag()
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
        if event.type == .leftMouseDown,
           event.clickCount == 2,
           isPointInSearchBar(event.locationInWindow) {
            resetPosition()
            onPositionChanged?(nil)
            return
        }

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
        setFrame(
            launcherPanelDefaultFrame(
                panelSize: frame.size,
                screenVisibleFrame: screen.visibleFrame
            ),
            display: true
        )
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

    private func isPointInSearchBar(_ point: NSPoint) -> Bool {
        NSRect(
            x: 0,
            y: frame.height - LauncherTheme.Metrics.searchHeight,
            width: frame.width,
            height: LauncherTheme.Metrics.searchHeight
        ).contains(point)
    }

    @objc
    private func windowWillMove(_ notification: Notification) {
        guard isVisible, !positioningProgrammatically, !isDraggingPanel else { return }
        isDraggingPanel = true
        updateSnapGuide()
        installMouseUpMonitors()
    }

    @objc
    private func windowDidMove(_ notification: Notification) {
        guard isDraggingPanel else { return }
        updateSnapGuide()
    }

    private func installMouseUpMonitors() {
        removeMouseUpMonitors()
        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) {
            [weak self] event in
            Task { @MainActor [weak self] in
                self?.finishDrag()
            }
            return event
        }
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finishDrag()
            }
        }
    }

    private func removeMouseUpMonitors() {
        if let localMouseUpMonitor {
            NSEvent.removeMonitor(localMouseUpMonitor)
            self.localMouseUpMonitor = nil
        }
        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
            self.globalMouseUpMonitor = nil
        }
    }

    private func updateSnapGuide() {
        guard let target = launcherPanelNearestDefaultFrame(
            panelFrame: frame,
            screenVisibleFrames: NSScreen.screens.map(\.visibleFrame)
        ) else {
            snapGuide.orderOut(nil)
            return
        }

        snapGuide.setFrame(target, display: true)
        snapGuide.level = level
        snapGuide.order(.below, relativeTo: windowNumber)
    }

    private func finishDrag() {
        guard isDraggingPanel else { return }
        isDraggingPanel = false
        removeMouseUpMonitors()
        snapGuide.orderOut(nil)

        if let target = launcherPanelSnapTarget(
            droppedFrame: frame,
            screenVisibleFrames: NSScreen.screens.map(\.visibleFrame)
        ) {
            positioningProgrammatically = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                animator().setFrame(target, display: true)
            }
            positioningProgrammatically = false
            onPositionChanged?(nil)
        } else {
            onPositionChanged?(
                LauncherWindowPosition(x: Double(frame.minX), y: Double(frame.minY))
            )
        }
    }

    private func cancelDrag() {
        guard isDraggingPanel else { return }
        isDraggingPanel = false
        removeMouseUpMonitors()
        snapGuide.orderOut(nil)
    }
}

private final class LauncherPanelSnapGuideWindow: NSWindow {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = LauncherPanelSnapGuideView()
    }
}

private final class LauncherPanelSnapGuideView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let lineWidth: CGFloat = 2
        let outline = NSBezierPath(
            roundedRect: bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2),
            xRadius: LauncherTheme.Metrics.panelCornerRadius,
            yRadius: LauncherTheme.Metrics.panelCornerRadius
        )
        outline.lineWidth = lineWidth
        outline.lineCapStyle = .round
        outline.setLineDash([1, 5], count: 2, phase: 0)
        NSColor.secondaryLabelColor.setStroke()
        outline.stroke()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
