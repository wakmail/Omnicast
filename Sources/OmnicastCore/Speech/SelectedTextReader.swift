// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import Foundation

@MainActor
public protocol SelectedTextReading: AnyObject, Sendable {
    func selectedText() async -> String?
}

@MainActor
public final class FrontmostSelectedTextReader: SelectedTextReading {
    private let workspace: NSWorkspace
    private let pasteboard: NSPasteboard
    private let snapshotter: any RestorablePasteboard

    public init(
        workspace: NSWorkspace = .shared,
        pasteboard: NSPasteboard = .general
    ) {
        self.workspace = workspace
        self.pasteboard = pasteboard
        self.snapshotter = SystemRestorablePasteboard(pasteboard: pasteboard)
    }

    public func selectedText() async -> String? {
        if let text = selectedTextUsingAccessibility() {
            return text
        }
        return await selectedTextUsingClipboard()
    }

    private func selectedTextUsingAccessibility() -> String? {
        var roots: [AXUIElement] = []
        if let application = workspace.frontmostApplication {
            let app = AXUIElementCreateApplication(application.processIdentifier)
            AXUIElementSetAttributeValue(
                app,
                "AXEnhancedUserInterface" as CFString,
                kCFBooleanTrue
            )
            AXUIElementSetAttributeValue(
                app,
                "AXManualAccessibility" as CFString,
                kCFBooleanTrue
            )
            if let focused = elementAttribute(app, kAXFocusedUIElementAttribute as CFString) {
                roots.append(focused)
            }
            if let window = elementAttribute(app, kAXFocusedWindowAttribute as CFString) {
                roots.append(window)
            }
        }
        let system = AXUIElementCreateSystemWide()
        if let focused = elementAttribute(system, kAXFocusedUIElementAttribute as CFString) {
            roots.append(focused)
        }
        return findSelectedText(roots: roots)
    }

    private func findSelectedText(roots: [AXUIElement]) -> String? {
        var queue = roots.map { ($0, 0) }
        var index = 0
        while index < queue.count, index < 240 {
            let (element, depth) = queue[index]
            index += 1
            if let text = selectedText(from: element) { return text }
            guard depth < 8 else { continue }
            if let focused = elementAttribute(element, kAXFocusedUIElementAttribute as CFString) {
                queue.append((focused, depth + 1))
            }
            if let children = copyAttribute(element, kAXChildrenAttribute as CFString)
                as? [AXUIElement] {
                queue.append(contentsOf: children.map { ($0, depth + 1) })
            }
        }
        return nil
    }

    private func selectedText(from element: AXUIElement) -> String? {
        let role = copyAttribute(element, kAXRoleAttribute as CFString) as? String
        let subrole = copyAttribute(element, kAXSubroleAttribute as CFString) as? String
        if role == "AXSecureTextField" || subrole == kAXSecureTextFieldSubrole as String {
            return nil
        }
        if let text = stringValue(
            copyAttribute(element, kAXSelectedTextAttribute as CFString)
        ) {
            return text
        }
        if let text = selectedTextUsingMarkers(element) { return text }
        guard let rangeValue = copyAttribute(
            element,
            kAXSelectedTextRangeAttribute as CFString
        ), let range = range(from: rangeValue), range.length > 0 else {
            return nil
        }
        let parameterizedAttributes: [CFString] = [
            kAXStringForRangeParameterizedAttribute as CFString,
            kAXAttributedStringForRangeParameterizedAttribute as CFString,
            "AXStringForRange" as CFString,
            "AXAttributedStringForRange" as CFString
        ]
        for attribute in parameterizedAttributes {
            if let text = stringValue(
                copyParameterizedAttribute(element, attribute, rangeValue)
            ) {
                return text
            }
        }
        return selectedTextUsingValue(element, range: range)
    }

    private func selectedTextUsingMarkers(_ element: AXUIElement) -> String? {
        guard let range = copyAttribute(
            element,
            "AXSelectedTextMarkerRange" as CFString
        ) else { return nil }
        for attribute in [
            "AXStringForTextMarkerRange" as CFString,
            "AXAttributedStringForTextMarkerRange" as CFString
        ] {
            if let text = stringValue(copyParameterizedAttribute(element, attribute, range)) {
                return text
            }
        }
        return nil
    }

    private func selectedTextUsingValue(
        _ element: AXUIElement,
        range: CFRange
    ) -> String? {
        guard let value = copyAttribute(element, kAXValueAttribute as CFString) as? String else {
            return nil
        }
        let characters = value.utf16
        guard let start = characters.index(
            characters.startIndex,
            offsetBy: range.location,
            limitedBy: characters.endIndex
        ), let end = characters.index(
            start,
            offsetBy: range.length,
            limitedBy: characters.endIndex
        ) else { return nil }
        let text = String(characters[start..<end]) ?? ""
        return text.isEmpty ? nil : text
    }

    private func selectedTextUsingClipboard() async -> String? {
        let snapshot = snapshotter.snapshot()
        defer { snapshotter.restore(snapshot) }
        pasteboard.clearContents()
        guard postCopyEvents() else { return nil }
        try? await Task.sleep(nanoseconds: 120_000_000)
        let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text : nil
    }

    private func postCopyEvents() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: true
              ),
              let up = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: false
              ) else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}

private func copyAttribute(_ element: AXUIElement, _ attribute: CFString) -> AnyObject? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
        return nil
    }
    return value
}

private func copyParameterizedAttribute(
    _ element: AXUIElement,
    _ attribute: CFString,
    _ parameter: AnyObject
) -> AnyObject? {
    var value: AnyObject?
    guard AXUIElementCopyParameterizedAttributeValue(
        element,
        attribute,
        parameter,
        &value
    ) == .success else { return nil }
    return value
}

private func elementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
    guard let value = copyAttribute(element, attribute),
          CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return unsafeBitCast(value, to: AXUIElement.self)
}

private func stringValue(_ value: AnyObject?) -> String? {
    guard let value else { return nil }
    let text: String?
    if let string = value as? String {
        text = string
    } else if let attributed = value as? NSAttributedString {
        text = attributed.string
    } else {
        text = nil
    }
    guard let text, !text.isEmpty else { return nil }
    return text
}

private func range(from value: AnyObject) -> CFRange? {
    guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var range = CFRange()
    guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
    return range
}
