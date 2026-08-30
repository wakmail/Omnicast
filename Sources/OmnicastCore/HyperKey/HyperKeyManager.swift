// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import Foundation

public enum HyperKeyError: LocalizedError, Sendable {
    case eventTapUnavailable
    case runLoopSourceUnavailable
    case invalidMappingData
    case mappingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .eventTapUnavailable:
            "Input Monitoring or Accessibility permission is required"
        case .runLoopSourceUnavailable:
            "The Hyper key event source could not be created"
        case .invalidMappingData:
            "The keyboard mapping data is invalid"
        case .mappingFailed(let message):
            message
        }
    }
}

@MainActor
public final class HyperKeyManager {
    public private(set) var settings: HyperKeySettings
    public let remapTarget: HyperKeyRemapTarget
    public private(set) var isRunning = false

    private let mappingRunner: HyperKeyMappingRunner
    private let onOpenOmnicast: () -> Void
    private let eventPoster: (CGKeyCode, CGEventFlags) -> Void
    private let applicationLauncher: (String) -> Void
    private var eventState: HyperKeyEventState?
    private var runLoopSource: CFRunLoopSource?
    private var mappingApplied = false

    public init(
        settings: HyperKeySettings = HyperKeySettings(),
        remapTarget: HyperKeyRemapTarget = .function18,
        onOpenOmnicast: @escaping () -> Void = {},
        onOpenApplication: @escaping (String) -> Void = { _ in }
    ) {
        self.settings = settings
        self.remapTarget = remapTarget
        self.onOpenOmnicast = onOpenOmnicast
        eventPoster = postSyntheticShortcut
        applicationLauncher = onOpenApplication
        mappingRunner = HyperKeyMappingRunner()
    }

    init(
        settings: HyperKeySettings,
        remapTarget: HyperKeyRemapTarget = .function18,
        onOpenOmnicast: @escaping () -> Void = {},
        eventPoster: @escaping (CGKeyCode, CGEventFlags) -> Void,
        applicationLauncher: @escaping (String) -> Void = { _ in }
    ) {
        self.settings = settings
        self.remapTarget = remapTarget
        self.onOpenOmnicast = onOpenOmnicast
        self.eventPoster = eventPoster
        self.applicationLauncher = applicationLauncher
        mappingRunner = HyperKeyMappingRunner()
    }

    public var inputMonitoringGranted: Bool {
        CGPreflightListenEventAccess()
    }

    @discardableResult
    public func requestInputMonitoring() -> Bool {
        CGRequestListenEventAccess()
    }

    public func update(_ settings: HyperKeySettings) throws {
        try disable()
        self.settings = settings
        if settings.enabled {
            try enable()
        }
    }

    public func enable() throws {
        guard settings.enabled, !isRunning else { return }

        let usesMapping = settings.tapAction != .toggleCapsLock
        if usesMapping {
            try mappingRunner.apply(target: remapTarget)
            mappingApplied = true
        }

        do {
            let sourceCode: CGKeyCode
            switch (settings.tapAction, remapTarget) {
            case (.toggleCapsLock, _): sourceCode = 57
            case (_, .function18): sourceCode = 79
            case (_, .rightControl): sourceCode = 62
            }
            try installEventTap(
                sourceCode: sourceCode,
                sourceIsRemapped: usesMapping,
                tapAction: settings.tapAction
            )
            isRunning = true
        } catch {
            if mappingApplied {
                try? mappingRunner.removeCapsLockMapping()
                mappingApplied = false
            }
            throw error
        }
    }

    public func disable() throws {
        defer { isRunning = false }
        removeEventTap()
        if mappingApplied {
            try mappingRunner.removeCapsLockMapping()
            mappingApplied = false
        }
    }

    private func installEventTap(
        sourceCode: CGKeyCode,
        sourceIsRemapped: Bool,
        tapAction: HyperKeyTapAction
    ) throws {
        let tapStateMachine = HyperKeyTapStateMachine(
            action: tapAction,
            eventPoster: eventPoster,
            openOmnicast: onOpenOmnicast,
            applicationLauncher: applicationLauncher
        )
        let state = HyperKeyEventState(
            sourceCode: sourceCode,
            sourceIsRemapped: sourceIsRemapped,
            tapStateMachine: tapStateMachine,
            rightControlSource: sourceIsRemapped && remapTarget == .rightControl
        )
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hyperKeyEventCallback,
            userInfo: Unmanaged.passUnretained(state).toOpaque()
        ) else {
            throw HyperKeyError.eventTapUnavailable
        }
        state.eventTap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            throw HyperKeyError.runLoopSourceUnavailable
        }
        eventState = state
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func removeEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventState?.eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        eventState = nil
    }
}

private let hyperSyntheticMarker: Int64 = 0x534348594B
private let hyperFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

private final class HyperKeyEventState {
    let sourceCode: CGKeyCode
    let sourceIsRemapped: Bool
    let tapStateMachine: HyperKeyTapStateMachine
    let rightControlSource: Bool
    var eventTap: CFMachPort?

    init(
        sourceCode: CGKeyCode,
        sourceIsRemapped: Bool,
        tapStateMachine: HyperKeyTapStateMachine,
        rightControlSource: Bool
    ) {
        self.sourceCode = sourceCode
        self.sourceIsRemapped = sourceIsRemapped
        self.tapStateMachine = tapStateMachine
        self.rightControlSource = rightControlSource
    }

    var isCapsLockToggle: Bool {
        !sourceIsRemapped && sourceCode == 57
    }

    func isSource(_ keyCode: CGKeyCode) -> Bool {
        keyCode == sourceCode || sourceIsRemapped && keyCode == 57
    }
}

final class HyperKeyTapStateMachine {
    private(set) var sourceKeyDown = false
    private(set) var comboFired = false
    private(set) var pressSequence = 0

    private let action: HyperKeyTapAction
    private let eventPoster: (CGKeyCode, CGEventFlags) -> Void
    private let openOmnicast: () -> Void
    private let applicationLauncher: (String) -> Void

    init(
        action: HyperKeyTapAction,
        eventPoster: @escaping (CGKeyCode, CGEventFlags) -> Void,
        openOmnicast: @escaping () -> Void = {},
        applicationLauncher: @escaping (String) -> Void = { _ in }
    ) {
        self.action = action
        self.eventPoster = eventPoster
        self.openOmnicast = openOmnicast
        self.applicationLauncher = applicationLauncher
    }

    @discardableResult
    func beginSourcePress() -> Int {
        guard !sourceKeyDown else { return pressSequence }
        return restartSourcePress()
    }

    @discardableResult
    func restartSourcePress() -> Int {
        sourceKeyDown = true
        comboFired = false
        pressSequence &+= 1
        return pressSequence
    }

    func markComboFired() {
        guard sourceKeyDown else { return }
        comboFired = true
    }

    func endSourcePress() {
        guard sourceKeyDown else { return }
        sourceKeyDown = false
        if !comboFired {
            performTapAction()
        }
    }

    func expireSourcePress(sequence: Int) {
        guard sourceKeyDown, pressSequence == sequence else { return }
        sourceKeyDown = false
    }

    private func performTapAction() {
        switch action {
        case .none, .toggleCapsLock:
            break
        case .escape:
            eventPoster(53, [])
        case .openOmnicast:
            openOmnicast()
        case .keyboardShortcut(let keyCode, let modifiers):
            eventPoster(CGKeyCode(keyCode), CGEventFlags(rawValue: modifiers))
        case .openApplication(let bundleIdentifier):
            applicationLauncher(bundleIdentifier)
        }
    }
}

private let hyperKeyEventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let state = Unmanaged<HyperKeyEventState>.fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = state.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }
    if event.getIntegerValueField(.eventSourceUserData) == hyperSyntheticMarker {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let isSource = state.isSource(keyCode)
    let tapStateMachine = state.tapStateMachine

    if state.isCapsLockToggle && isSource && type == .flagsChanged {
        let sequence = tapStateMachine.restartSourcePress()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            tapStateMachine.expireSourcePress(sequence: sequence)
        }
        return Unmanaged.passUnretained(event)
    }

    if state.sourceIsRemapped && isSource {
        if type == .keyDown {
            tapStateMachine.beginSourcePress()
            return nil
        }
        if type == .keyUp {
            tapStateMachine.endSourcePress()
            return nil
        }
        if type == .flagsChanged {
            let isDown = state.rightControlSource
                ? event.flags.contains(.maskControl)
                : !tapStateMachine.sourceKeyDown
            if isDown && !tapStateMachine.sourceKeyDown {
                tapStateMachine.beginSourcePress()
            } else if !isDown && tapStateMachine.sourceKeyDown {
                tapStateMachine.endSourcePress()
            }
            return nil
        }
    }

    if tapStateMachine.sourceKeyDown && !isSource && (type == .keyDown || type == .keyUp) {
        if type == .keyDown {
            tapStateMachine.markComboFired()
        }
        event.flags.formUnion(hyperFlags)
        return Unmanaged.passUnretained(event)
    }
    return Unmanaged.passUnretained(event)
}

private func postSyntheticShortcut(_ keyCode: CGKeyCode, _ flags: CGEventFlags) {
    guard
        let source = CGEventSource(stateID: .hidSystemState),
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
    else {
        return
    }
    down.flags = flags
    up.flags = flags
    down.setIntegerValueField(.eventSourceUserData, value: hyperSyntheticMarker)
    up.setIntegerValueField(.eventSourceUserData, value: hyperSyntheticMarker)
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}
