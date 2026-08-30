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
    private var eventState: HyperKeyEventState?
    private var runLoopSource: CFRunLoopSource?
    private var mappingApplied = false

    public init(
        settings: HyperKeySettings = HyperKeySettings(),
        remapTarget: HyperKeyRemapTarget = .function18
    ) {
        self.settings = settings
        self.remapTarget = remapTarget
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

        let usesMapping = settings.mode != .toggle
        if usesMapping {
            try mappingRunner.apply(target: remapTarget)
            mappingApplied = true
        }

        do {
            let sourceCode: CGKeyCode
            switch (settings.mode, remapTarget) {
            case (.toggle, _): sourceCode = 57
            case (_, .function18): sourceCode = 79
            case (_, .rightControl): sourceCode = 62
            }
            try installEventTap(
                sourceCode: sourceCode,
                sourceIsRemapped: usesMapping,
                mode: settings.mode
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
        mode: HyperKeyMode
    ) throws {
        let state = HyperKeyEventState(
            sourceCode: sourceCode,
            sourceIsRemapped: sourceIsRemapped,
            mode: mode,
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
    let mode: HyperKeyMode
    let rightControlSource: Bool
    var sourceKeyDown = false
    var comboFired = false
    var pressSequence = 0
    var eventTap: CFMachPort?

    init(
        sourceCode: CGKeyCode,
        sourceIsRemapped: Bool,
        mode: HyperKeyMode,
        rightControlSource: Bool
    ) {
        self.sourceCode = sourceCode
        self.sourceIsRemapped = sourceIsRemapped
        self.mode = mode
        self.rightControlSource = rightControlSource
    }

    var isCapsLockToggle: Bool {
        !sourceIsRemapped && sourceCode == 57 && mode == .toggle
    }

    func isSource(_ keyCode: CGKeyCode) -> Bool {
        keyCode == sourceCode || sourceIsRemapped && keyCode == 57
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

    if state.isCapsLockToggle && isSource && type == .flagsChanged {
        state.sourceKeyDown = true
        state.comboFired = false
        state.pressSequence &+= 1
        let sequence = state.pressSequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if state.sourceKeyDown && state.pressSequence == sequence {
                state.sourceKeyDown = false
            }
        }
        return Unmanaged.passUnretained(event)
    }

    if state.sourceIsRemapped && isSource {
        if type == .keyDown {
            if !state.sourceKeyDown {
                state.sourceKeyDown = true
                state.comboFired = false
                state.pressSequence &+= 1
            }
            return nil
        }
        if type == .keyUp {
            if state.sourceKeyDown {
                state.sourceKeyDown = false
                if !state.comboFired {
                    handleHyperTap(mode: state.mode)
                }
            }
            return nil
        }
        if type == .flagsChanged {
            let isDown = state.rightControlSource
                ? event.flags.contains(.maskControl)
                : !state.sourceKeyDown
            if isDown && !state.sourceKeyDown {
                state.sourceKeyDown = true
                state.comboFired = false
                state.pressSequence &+= 1
            } else if !isDown && state.sourceKeyDown {
                state.sourceKeyDown = false
                if !state.comboFired {
                    handleHyperTap(mode: state.mode)
                }
            }
            return nil
        }
    }

    if state.sourceKeyDown && !isSource && (type == .keyDown || type == .keyUp) {
        if type == .keyDown {
            state.comboFired = true
        }
        event.flags.formUnion(hyperFlags)
        return Unmanaged.passUnretained(event)
    }
    return Unmanaged.passUnretained(event)
}

private func handleHyperTap(mode: HyperKeyMode) {
    guard mode == .escape else { return }
    postSyntheticKey(53)
}

private func postSyntheticKey(_ keyCode: CGKeyCode) {
    guard
        let source = CGEventSource(stateID: .hidSystemState),
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
    else {
        return
    }
    down.setIntegerValueField(.eventSourceUserData, value: hyperSyntheticMarker)
    up.setIntegerValueField(.eventSourceUserData, value: hyperSyntheticMarker)
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}
