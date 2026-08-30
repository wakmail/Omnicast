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
    private let alignmentGuide = LauncherPanelAlignmentGuideWindow()
    private(set) var hiddenAt: Date?

    init(keyEvents: LauncherKeyEvents, windowMode: LauncherWindowMode = .standard) {
        self.keyEvents = keyEvents
        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: LauncherTheme.Metrics.panelWidth,
                height: LauncherTheme.Metrics.panelHeight(for: windowMode)
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
        hiddenAt = nil
    }

    func resetPosition() {
        cancelDrag()
        positioningProgrammatically = true
        setDefaultPosition()
        positioningProgrammatically = false
    }

    func hide(returningFocus: Bool) {
        cancelDrag()
        hiddenAt = Date()
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

    func setWindowMode(_ windowMode: LauncherWindowMode) {
        let newHeight = LauncherTheme.Metrics.panelHeight(for: windowMode)
        guard frame.height != newHeight else { return }
        var newFrame = frame
        newFrame.origin.y += frame.height - newHeight
        newFrame.size.height = newHeight
        setFrame(newFrame, display: true, animate: isVisible)
    }

    func shouldResetNavigationOnShow(
        timeout: TimeInterval,
        now: Date = Date()
    ) -> Bool {
        shouldPopLauncherToRoot(hiddenAt: hiddenAt, shownAt: now, timeout: timeout)
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
            if keyEvents.route(.actions) { return }
            super.sendEvent(event)
            return
        }
        if modifiers.contains(.command), event.keyCode == 43 {
            if keyEvents.route(.settings) { return }
            super.sendEvent(event)
            return
        }
        if modifiers.contains(.command), (event.keyCode == 36 || event.keyCode == 76) {
            if keyEvents.route(.commandEnter) { return }
            super.sendEvent(event)
            return
        }

        let key: LauncherKey?
        switch event.keyCode {
        case 126:
            key = .moveUp
        case 125:
            key = .moveDown
        case 36, 76:
            key = .enter
        case 53:
            key = .escape
        default:
            key = nil
        }
        if let key, keyEvents.route(key) {
            return
        } else {
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
        updateAlignmentGuides()
        installMouseUpMonitors()
    }

    @objc
    private func windowDidMove(_ notification: Notification) {
        guard isDraggingPanel, !positioningProgrammatically else { return }
        updateAlignmentGuides()
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

    private func updateAlignmentGuides() {
        guard let alignment = launcherPanelGuideAlignment(
            panelFrame: frame,
            screenVisibleFrames: NSScreen.screens.map(\.visibleFrame)
        ) else {
            alignmentGuide.orderOut(nil)
            return
        }

        if alignment.magnetizedFrame.origin != frame.origin {
            positioningProgrammatically = true
            setFrameOrigin(alignment.magnetizedFrame.origin)
            positioningProgrammatically = false
        }

        alignmentGuide.show(alignment: alignment, above: level)
    }

    private func finishDrag() {
        guard isDraggingPanel else { return }
        isDraggingPanel = false
        removeMouseUpMonitors()
        alignmentGuide.orderOut(nil)

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
        alignmentGuide.orderOut(nil)
    }
}

private final class LauncherPanelAlignmentGuideWindow: NSWindow {
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
        contentView = LauncherPanelAlignmentGuideView()
    }

    func show(alignment: LauncherPanelGuideAlignment, above panelLevel: NSWindow.Level) {
        guard alignment.hasActiveGuide,
              let guideView = contentView as? LauncherPanelAlignmentGuideView
        else {
            orderOut(nil)
            return
        }

        setFrame(alignment.screenVisibleFrame, display: true)
        guideView.verticalGuideX = alignment.verticalGuideX.map {
            $0 - alignment.screenVisibleFrame.minX
        }
        guideView.horizontalGuideY = alignment.horizontalGuideY.map {
            $0 - alignment.screenVisibleFrame.minY
        }
        level = NSWindow.Level(rawValue: panelLevel.rawValue + 1)
        orderFrontRegardless()
    }
}

private final class LauncherPanelAlignmentGuideView: NSView {
    var verticalGuideX: CGFloat? {
        didSet { needsDisplay = true }
    }
    var horizontalGuideY: CGFloat? {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()

        if let verticalGuideX {
            strokeGuide(
                from: NSPoint(x: verticalGuideX, y: bounds.minY),
                to: NSPoint(x: verticalGuideX, y: bounds.maxY)
            )
        }
        if let horizontalGuideY {
            strokeGuide(
                from: NSPoint(x: bounds.minX, y: horizontalGuideY),
                to: NSPoint(x: bounds.maxX, y: horizontalGuideY)
            )
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    private func strokeGuide(from start: NSPoint, to end: NSPoint) {
        let guide = NSBezierPath()
        guide.move(to: start)
        guide.line(to: end)
        guide.lineWidth = 1
        guide.lineCapStyle = .round
        guide.setLineDash([1, 3], count: 2, phase: 0)
        guide.stroke()
    }
}
