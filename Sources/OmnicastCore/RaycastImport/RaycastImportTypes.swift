// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum RaycastImportCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case settings
    case hotkeys
    case extensions
    case scriptDirectories
    case quicklinks
    case snippets
    case notes
    case extensionPreferences

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .settings: return "Settings"
        case .hotkeys: return "Hotkeys"
        case .extensions: return "Extensions"
        case .scriptDirectories: return "Script Directories"
        case .quicklinks: return "Quick Links"
        case .snippets: return "Snippets"
        case .notes: return "Notes"
        case .extensionPreferences: return "Extension Preferences"
        }
    }
}

public struct RaycastImportSelections: Equatable, Sendable {
    public var selectedCategories: Set<RaycastImportCategory>

    public init(selectedCategories: Set<RaycastImportCategory> = Set(RaycastImportCategory.allCases)) {
        self.selectedCategories = selectedCategories
    }

    public func contains(_ category: RaycastImportCategory) -> Bool {
        selectedCategories.contains(category)
    }
}

public struct RaycastCategoryImportResult: Equatable, Sendable {
    public let category: RaycastImportCategory
    public let selected: Bool
    public let found: Int
    public let imported: Int
    public let skipped: Int
    public let failed: Int

    public init(
        category: RaycastImportCategory,
        selected: Bool,
        found: Int,
        imported: Int,
        skipped: Int,
        failed: Int
    ) {
        self.category = category
        self.selected = selected
        self.found = found
        self.imported = imported
        self.skipped = skipped
        self.failed = failed
    }
}

public struct RaycastImportIssue: Equatable, Sendable, Identifiable {
    public let category: RaycastImportCategory
    public let item: String
    public let reason: String

    public var id: String { "\(category.rawValue):\(item):\(reason)" }

    public init(category: RaycastImportCategory, item: String, reason: String) {
        self.category = category
        self.item = item
        self.reason = reason
    }
}

public struct RaycastImportResult: Equatable, Sendable {
    public let raycastVersion: String?
    public let categories: [RaycastImportCategory: RaycastCategoryImportResult]
    public let skippedItems: [RaycastImportIssue]
    public let extensionsToInstall: [String]

    public init(
        raycastVersion: String?,
        categories: [RaycastImportCategory: RaycastCategoryImportResult],
        skippedItems: [RaycastImportIssue],
        extensionsToInstall: [String]
    ) {
        self.raycastVersion = raycastVersion
        self.categories = categories
        self.skippedItems = skippedItems
        self.extensionsToInstall = extensionsToInstall
    }

    public var importedCount: Int {
        categories.values.reduce(0) { $0 + $1.imported }
    }
}

public struct RaycastImportedCommandHotkey: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var displayName: String

    public init(keyCode: UInt32, modifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }
}

public struct RaycastSupplementalImportData: Codable, Equatable, Sendable {
    public var scriptDirectories: [String]
    public var commandHotkeys: [String: RaycastImportedCommandHotkey]
    public var disabledCommandKeys: [String]

    public init(
        scriptDirectories: [String] = [],
        commandHotkeys: [String: RaycastImportedCommandHotkey] = [:],
        disabledCommandKeys: [String] = []
    ) {
        self.scriptDirectories = scriptDirectories
        self.commandHotkeys = commandHotkeys
        self.disabledCommandKeys = disabledCommandKeys
    }
}
