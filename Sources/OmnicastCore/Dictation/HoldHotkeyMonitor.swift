// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import Foundation

@MainActor
public final class HoldHotkeyMonitor {
    public struct Configuration: Equatable, Sendable {
        public var keyCode: CGKeyCode
        public var requiredFlags: CGEventFlags

        public init(keyCode: CGKeyCode, requiredFlags: CGEventFlags = []) {
            self.keyCode = keyCode
            self.requiredFlags = requiredFlags
        }

        public static let function = Configuration(
            keyCode: 63,
            requiredFlags: .maskSecondaryFn
        )
        public static let rightCommand = Configuration(
            keyCode: 54,
            requiredFlags: .maskCommand
        )
    }

    public var onPressed: (() -> Void)?
    public var onReleased: (() -> Void)?

    private let configuration: Configuration
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isPressed = false

    public init(configuration: Configuration = .function) {
        self.configuration = configuration
    }

    public func start() throws {
        guard eventTap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: holdHotkeyCallback,
            userInfo: pointer
        ) else {
            throw HoldHotkeyError.couldNotCreateEventTap
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            throw HoldHotkeyError.couldNotCreateRunLoopSource
        }
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isPressed = false
    }

    fileprivate func handle(type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) {
        let modifiersMatch = relevantFlags(flags) == relevantFlags(configuration.requiredFlags)
        if !isPressed,
           (type == .keyDown || type == .flagsChanged),
           keyCode == configuration.keyCode,
           modifiersMatch {
            isPressed = true
            onPressed?()
            return
        }

        guard isPressed else { return }
        if (type == .keyUp && keyCode == configuration.keyCode) || !modifiersMatch {
            isPressed = false
            onReleased?()
        }
    }

    private func relevantFlags(_ flags: CGEventFlags) -> CGEventFlags {
        flags.intersection([
            .maskCommand,
            .maskControl,
            .maskAlternate,
            .maskShift,
            .maskSecondaryFn
        ])
    }
}

public enum HoldHotkeyError: LocalizedError {
    case couldNotCreateEventTap
    case couldNotCreateRunLoopSource

    public var errorDescription: String? {
        switch self {
        case .couldNotCreateEventTap:
            return "Input Monitoring or Accessibility permission is required"
        case .couldNotCreateRunLoopSource:
            return "The hold shortcut monitor could not start"
        }
    }
}

private let holdHotkeyCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        return Unmanaged.passUnretained(event)
    }
    let monitor = Unmanaged<HoldHotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags
    Task { @MainActor in
        monitor.handle(type: type, keyCode: keyCode, flags: flags)
    }
    return Unmanaged.passUnretained(event)
}
