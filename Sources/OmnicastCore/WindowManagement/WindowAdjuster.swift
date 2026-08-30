// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import Foundation

public final class WindowAdjuster: @unchecked Sendable {
    public init() {}

    public var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    @MainActor
    public func apply(_ placement: WindowPlacement) throws {
        guard accessibilityGranted else {
            throw WindowAdjustmentError.accessibilityPermissionRequired
        }
        guard let window = focusedWindow() else {
            throw WindowAdjustmentError.focusedWindowUnavailable
        }
        guard let current = readFrame(of: window) else {
            throw WindowAdjustmentError.windowFrameUnavailable
        }
        guard let visibleFrame = visibleBounds(for: current) else {
            throw WindowAdjustmentError.displayUnavailable
        }

        let target = frame(for: placement, in: visibleFrame, current: current)
        guard setFrame(target, on: window) else {
            throw WindowAdjustmentError.adjustmentFailed
        }
    }
}

public enum WindowAdjustmentError: LocalizedError, Sendable {
    case accessibilityPermissionRequired
    case focusedWindowUnavailable
    case windowFrameUnavailable
    case displayUnavailable
    case adjustmentFailed

    public var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            "Accessibility permission is required"
        case .focusedWindowUnavailable:
            "No focused window is available"
        case .windowFrameUnavailable:
            "The focused window frame could not be read"
        case .displayUnavailable:
            "The window display could not be found"
        case .adjustmentFailed:
            "The focused window could not be adjusted"
        }
    }
}

@MainActor
private func focusedWindow() -> AXUIElement? {
    if let application = NSWorkspace.shared.frontmostApplication {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        if let window = windowAttribute(appElement, kAXFocusedWindowAttribute as CFString) {
            return window
        }
        if let window = windowAttribute(appElement, kAXMainWindowAttribute as CFString) {
            return window
        }
        if let windows = copyAttribute(appElement, kAXWindowsAttribute as CFString) as? [AXUIElement] {
            return windows.first { attributeString($0, kAXRoleAttribute as CFString) == kAXWindowRole as String }
        }
    }

    let system = AXUIElementCreateSystemWide()
    guard let application = elementAttribute(system, kAXFocusedApplicationAttribute as CFString) else {
        return nil
    }
    return windowAttribute(application, kAXFocusedWindowAttribute as CFString)
}

private func windowAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
    guard let value = elementAttribute(element, attribute) else { return nil }
    guard attributeString(value, kAXRoleAttribute as CFString) == kAXWindowRole as String else {
        return nil
    }
    return value
}

private func elementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
    guard let raw = copyAttribute(element, attribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else {
        return nil
    }
    return unsafeBitCast(raw, to: AXUIElement.self)
}

private func copyAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
        return nil
    }
    return value
}

private func attributeString(_ element: AXUIElement, _ attribute: CFString) -> String? {
    copyAttribute(element, attribute) as? String
}

private func readFrame(of window: AXUIElement) -> CGRect? {
    guard
        let position = decodePoint(copyAttribute(window, kAXPositionAttribute as CFString)),
        let size = decodeSize(copyAttribute(window, kAXSizeAttribute as CFString))
    else {
        return nil
    }
    return CGRect(
        x: position.x,
        y: position.y,
        width: max(1, size.width),
        height: max(1, size.height)
    )
}

private func decodePoint(_ raw: CFTypeRef?) -> CGPoint? {
    guard let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
    let value = unsafeBitCast(raw, to: AXValue.self)
    guard AXValueGetType(value) == .cgPoint else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(value, .cgPoint, &point) ? point : nil
}

private func decodeSize(_ raw: CFTypeRef?) -> CGSize? {
    guard let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
    let value = unsafeBitCast(raw, to: AXValue.self)
    guard AXValueGetType(value) == .cgSize else { return nil }
    var size = CGSize.zero
    return AXValueGetValue(value, .cgSize, &size) ? size : nil
}

private func setFrame(_ frame: CGRect, on window: AXUIElement) -> Bool {
    var processIdentifier: pid_t = 0
    var originalEnhancedUI: CFTypeRef?
    let hasApplication = AXUIElementGetPid(window, &processIdentifier) == .success && processIdentifier > 0
    if hasApplication {
        let application = AXUIElementCreateApplication(processIdentifier)
        AXUIElementCopyAttributeValue(
            application,
            "AXEnhancedUserInterface" as CFString,
            &originalEnhancedUI
        )
        AXUIElementSetAttributeValue(
            application,
            "AXEnhancedUserInterface" as CFString,
            kCFBooleanFalse
        )
    }

    var point = frame.origin
    guard let pointValue = AXValueCreate(.cgPoint, &point) else { return false }
    let pointStatus = AXUIElementSetAttributeValue(
        window,
        kAXPositionAttribute as CFString,
        pointValue
    )

    var size = frame.size
    guard let sizeValue = AXValueCreate(.cgSize, &size) else { return false }
    let sizeStatus = AXUIElementSetAttributeValue(
        window,
        kAXSizeAttribute as CFString,
        sizeValue
    )

    if hasApplication {
        let application = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetAttributeValue(
            application,
            "AXEnhancedUserInterface" as CFString,
            originalEnhancedUI ?? kCFBooleanFalse
        )
    }
    return pointStatus == .success && sizeStatus == .success
}

@MainActor
private func visibleBounds(for windowFrame: CGRect) -> CGRect? {
    let displayIdentifier = bestDisplayIdentifier(for: windowFrame) ?? CGMainDisplayID()
    let displayBounds = CGDisplayBounds(displayIdentifier)
    guard displayBounds.width > 0, displayBounds.height > 0 else { return nil }

    guard let screen = NSScreen.screens.first(where: {
        guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }
        return CGDirectDisplayID(number.uint32Value) == displayIdentifier
    }) else {
        return displayBounds
    }

    let screenFrame = screen.frame
    let screenVisibleFrame = screen.visibleFrame
    let visibleLeft = displayBounds.minX + screenVisibleFrame.minX - screenFrame.minX
    let visibleTop = displayBounds.minY + screenFrame.maxY - screenVisibleFrame.maxY
    let visibleArea = CGRect(
        x: visibleLeft,
        y: visibleTop,
        width: screenVisibleFrame.width,
        height: screenVisibleFrame.height
    )
    return reserveVisibleDockSpace(
        in: visibleArea,
        displayBounds: displayBounds,
        screenFrame: screenFrame,
        screenVisibleFrame: screenVisibleFrame
    )
}

private func bestDisplayIdentifier(for rect: CGRect) -> CGDirectDisplayID? {
    guard
        !rect.isNull,
        !rect.isInfinite,
        rect.minX.isFinite,
        rect.minY.isFinite,
        rect.width.isFinite,
        rect.height.isFinite,
        rect.width > 0,
        rect.height > 0
    else {
        return nil
    }

    var identifiers = [CGDirectDisplayID](repeating: 0, count: 32)
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(UInt32(identifiers.count), &identifiers, &count) == .success else {
        return nil
    }

    var bestIdentifier: CGDirectDisplayID?
    var bestArea: CGFloat = -1
    for identifier in identifiers.prefix(Int(count)) {
        let intersection = CGDisplayBounds(identifier).intersection(rect)
        let area = intersection.isNull ? 0 : intersection.width * intersection.height
        if area > bestArea {
            bestArea = area
            bestIdentifier = identifier
        }
    }
    return bestIdentifier
}

@MainActor
private func reserveVisibleDockSpace(
    in visibleArea: CGRect,
    displayBounds: CGRect,
    screenFrame: CGRect,
    screenVisibleFrame: CGRect
) -> CGRect {
    let settings = dockSettings()
    guard settings.autoHide, dockIsVisible(on: displayBounds) else { return visibleArea }

    var area = visibleArea
    switch settings.orientation {
    case "left" where screenVisibleFrame.minX - screenFrame.minX < 1:
        area.origin.x += settings.reserve
        area.size.width = max(1, area.width - settings.reserve)
    case "right" where screenFrame.maxX - screenVisibleFrame.maxX < 1:
        area.size.width = max(1, area.width - settings.reserve)
    case "bottom" where screenVisibleFrame.minY - screenFrame.minY < 1:
        area.size.height = max(1, area.height - settings.reserve)
    default:
        break
    }
    return area
}

private func dockSettings() -> (orientation: String, reserve: CGFloat, autoHide: Bool) {
    let defaults = UserDefaults(suiteName: "com.apple.dock")
    let rawOrientation = defaults?.string(forKey: "orientation") ?? "bottom"
    let orientation = ["left", "right"].contains(rawOrientation) ? rawOrientation : "bottom"
    let tileSize = CGFloat((defaults?.object(forKey: "tilesize") as? NSNumber)?.doubleValue ?? 45)
    return (orientation, max(48, tileSize + 17), defaults?.bool(forKey: "autohide") ?? false)
}

private func dockIsVisible(on displayBounds: CGRect) -> Bool {
    guard
        let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
    else {
        return false
    }
    let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
    guard let children = copyAttribute(dockElement, kAXChildrenAttribute as CFString) as? [AXUIElement] else {
        return false
    }

    for child in children {
        guard
            attributeString(child, kAXRoleAttribute as CFString) == kAXListRole as String,
            let position = decodePoint(copyAttribute(child, kAXPositionAttribute as CFString)),
            let size = decodeSize(copyAttribute(child, kAXSizeAttribute as CFString)),
            size.width > 0,
            size.height > 0
        else {
            continue
        }
        let intersection = CGRect(origin: position, size: size).intersection(displayBounds)
        return !intersection.isNull && intersection.width > 4 && intersection.height > 4
    }
    return false
}
