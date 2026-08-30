// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import Foundation

public struct MenuItemEntry: Equatable, Identifiable, Sendable {
    public var id: String { fullPath }
    public let path: String
    public let title: String
    public let fullPath: String
    public let shortcut: String?
    public let isEnabled: Bool

    public init(
        path: String,
        title: String,
        fullPath: String,
        shortcut: String? = nil,
        isEnabled: Bool = true
    ) {
        self.path = path
        self.title = title
        self.fullPath = fullPath
        self.shortcut = shortcut
        self.isEnabled = isEnabled
    }
}

public struct MenuItemSnapshot: Sendable {
    public let applicationName: String
    public let items: [MenuItemEntry]

    public init(applicationName: String, items: [MenuItemEntry]) {
        self.applicationName = applicationName
        self.items = items
    }
}

public struct MenuElementFixture: Equatable, Sendable {
    public let title: String
    public let shortcut: String?
    public let isEnabled: Bool
    public let children: [MenuElementFixture]

    public init(
        title: String,
        shortcut: String? = nil,
        isEnabled: Bool = true,
        children: [MenuElementFixture] = []
    ) {
        self.title = title
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.children = children
    }
}

public enum MenuItemTreeFlattener {
    public static func flatten(_ roots: [MenuElementFixture]) -> [MenuItemEntry] {
        var result: [MenuItemEntry] = []
        collect(roots, parentPath: "", result: &result)
        return result
    }

    private static func collect(
        _ nodes: [MenuElementFixture],
        parentPath: String,
        result: inout [MenuItemEntry]
    ) {
        for node in nodes {
            let title = node.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if title == "Apple" { continue }
            let currentPath = title.isEmpty
                ? parentPath
                : (parentPath.isEmpty ? title : "\(parentPath) > \(title)")
            if !node.children.isEmpty {
                collect(node.children, parentPath: currentPath, result: &result)
            } else if !title.isEmpty {
                result.append(MenuItemEntry(
                    path: parentPath,
                    title: title,
                    fullPath: currentPath,
                    shortcut: node.shortcut,
                    isEnabled: node.isEnabled
                ))
            }
        }
    }
}

public enum MenuItemIndexError: LocalizedError {
    case accessibilityNotGranted
    case noTargetApplication
    case menuBarUnavailable(String)
    case itemNotFound(String)
    case pressFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission is required"
        case .noTargetApplication:
            return "No target application is available"
        case .menuBarUnavailable(let name):
            return "Cannot access the menu bar for \(name)"
        case .itemNotFound(let path):
            return "Menu item not found: \(path)"
        case .pressFailed(let code):
            return "Could not press the menu item, error \(code)"
        }
    }
}

@MainActor
public final class MenuItemIndex {
    private let workspace: NSWorkspace
    private var targetApplication: NSRunningApplication?

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        captureTargetApplication()
    }

    public var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    public var targetApplicationName: String? {
        targetApplication?.localizedName
    }

    public func captureTargetApplication() {
        guard let application = workspace.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        targetApplication = application
    }

    public func read() throws -> MenuItemSnapshot {
        guard isAccessibilityGranted else {
            throw MenuItemIndexError.accessibilityNotGranted
        }
        let application = try resolvedApplication()
        let menuBar = try menuBar(for: application)
        let fixture = fixture(from: menuBar)
        return MenuItemSnapshot(
            applicationName: application.localizedName ?? "Application",
            items: MenuItemTreeFlattener.flatten(fixture.children)
        )
    }

    public func press(_ item: MenuItemEntry) async throws {
        guard isAccessibilityGranted else {
            throw MenuItemIndexError.accessibilityNotGranted
        }
        let application = try resolvedApplication()
        application.activate()
        try? await Task.sleep(nanoseconds: 120_000_000)
        let menuBar = try menuBar(for: application)
        guard let element = find(in: menuBar, parentPath: "", targetPath: item.fullPath) else {
            throw MenuItemIndexError.itemNotFound(item.fullPath)
        }
        let error = AXUIElementPerformAction(element, kAXPressAction as CFString)
        guard error == .success else {
            throw MenuItemIndexError.pressFailed(error.rawValue)
        }
    }

    private func resolvedApplication() throws -> NSRunningApplication {
        if let targetApplication, !targetApplication.isTerminated {
            return targetApplication
        }
        guard let application = workspace.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw MenuItemIndexError.noTargetApplication
        }
        targetApplication = application
        return application
    }

    private func menuBar(for application: NSRunningApplication) throws -> AXUIElement {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            appElement,
            kAXMenuBarAttribute as CFString,
            &value
        )
        guard error == .success, let value else {
            throw MenuItemIndexError.menuBarUnavailable(application.localizedName ?? "Application")
        }
        return value as! AXUIElement
    }

    private func fixture(from element: AXUIElement) -> MenuElementFixture {
        let title = stringAttribute(kAXTitleAttribute, element: element) ?? ""
        let enabled = boolAttribute(kAXEnabledAttribute, element: element) ?? true
        let children = elementChildren(element).map(fixture)
        return MenuElementFixture(
            title: title,
            shortcut: shortcut(for: element),
            isEnabled: enabled,
            children: children
        )
    }

    private func find(
        in element: AXUIElement,
        parentPath: String,
        targetPath: String
    ) -> AXUIElement? {
        for child in elementChildren(element) {
            let title = (stringAttribute(kAXTitleAttribute, element: child) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if title == "Apple" { continue }
            let currentPath = title.isEmpty
                ? parentPath
                : (parentPath.isEmpty ? title : "\(parentPath) > \(title)")
            let children = elementChildren(child)
            if !children.isEmpty {
                if let found = find(in: child, parentPath: currentPath, targetPath: targetPath) {
                    return found
                }
            } else if !title.isEmpty, currentPath == targetPath {
                return child
            }
        }
        return nil
    }

    private func elementChildren(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &value
        ) == .success else {
            return []
        }
        return value as? [AXUIElement] ?? []
    }

    private func stringAttribute(_ attribute: String, element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? String
    }

    private func intAttribute(_ attribute: String, element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? Int
    }

    private func boolAttribute(_ attribute: String, element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? Bool
    }

    private func shortcut(for element: AXUIElement) -> String? {
        let modifiers = intAttribute(kAXMenuItemCmdModifiersAttribute, element: element) ?? 0
        if let character = stringAttribute(kAXMenuItemCmdCharAttribute, element: element),
           !character.isEmpty {
            return Self.modifierString(modifiers) + Self.shortcutCharacter(character)
        }
        if let keyCode = intAttribute(kAXMenuItemCmdVirtualKeyAttribute, element: element),
           let key = Self.virtualKeyString(keyCode) {
            return Self.modifierString(modifiers) + key
        }
        return nil
    }

    nonisolated public static func modifierString(_ modifiers: Int) -> String {
        var result = ""
        if modifiers & 4 != 0 { result += "⌃" }
        if modifiers & 2 != 0 { result += "⌥" }
        if modifiers & 1 != 0 { result += "⇧" }
        if modifiers & 8 == 0 { result += "⌘" }
        return result
    }

    nonisolated public static func shortcutCharacter(_ character: String) -> String {
        guard let value = character.unicodeScalars.first?.value else { return character }
        switch value {
        case 0x08: return "⌫"
        case 0x09: return "⇥"
        case 0x0D, 0x03: return "↩"
        case 0x1B: return "⎋"
        case 0x7F: return "⌦"
        case 0x20: return "␣"
        case 0xF700: return "↑"
        case 0xF701: return "↓"
        case 0xF702: return "←"
        case 0xF703: return "→"
        case 0xF729: return "↖"
        case 0xF72B: return "↘"
        case 0xF72C: return "⇞"
        case 0xF72D: return "⇟"
        default: return character.count == 1 ? character.uppercased() : character
        }
    }

    nonisolated public static func virtualKeyString(_ code: Int) -> String? {
        let keys: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: ".", 47: "`", 49: "Space", 51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            103: "F11", 105: "F13", 107: "F14", 109: "F10", 111: "F12",
            113: "F15", 115: "↖", 116: "⇞", 117: "⌦", 118: "F4", 119: "End",
            120: "F2", 121: "⇟", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keys[code]
    }
}
