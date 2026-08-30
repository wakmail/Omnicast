// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct RaycastBackup: Codable, Equatable, Sendable {
    public var raycastVersion: String?
    public var quicklinksPackage: RaycastQuicklinksPackage?
    public var snippetsPackage: RaycastSnippetsPackage?
    public var notesPackage: RaycastNotesPackage?
    public var extensionsPackage: RaycastExtensionsPackage?
    public var preferencesPackage: RaycastPreferencesPackage?
    public var rootSearchPackage: RaycastRootSearchPackage?
    public var scriptCommandsPackage: RaycastScriptCommandsPackage?

    public init(
        raycastVersion: String? = nil,
        quicklinksPackage: RaycastQuicklinksPackage? = nil,
        snippetsPackage: RaycastSnippetsPackage? = nil,
        notesPackage: RaycastNotesPackage? = nil,
        extensionsPackage: RaycastExtensionsPackage? = nil,
        preferencesPackage: RaycastPreferencesPackage? = nil,
        rootSearchPackage: RaycastRootSearchPackage? = nil,
        scriptCommandsPackage: RaycastScriptCommandsPackage? = nil
    ) {
        self.raycastVersion = raycastVersion
        self.quicklinksPackage = quicklinksPackage
        self.snippetsPackage = snippetsPackage
        self.notesPackage = notesPackage
        self.extensionsPackage = extensionsPackage
        self.preferencesPackage = preferencesPackage
        self.rootSearchPackage = rootSearchPackage
        self.scriptCommandsPackage = scriptCommandsPackage
    }

    enum CodingKeys: String, CodingKey {
        case raycastVersion = "raycast_version"
        case quicklinksPackage = "builtin_package_quicklinks"
        case snippetsPackage = "builtin_package_snippets"
        case notesPackage = "builtin_package_raycastNotes"
        case extensionsPackage = "builtin_package_raycastExtensions"
        case preferencesPackage = "builtin_package_raycastPreferences"
        case rootSearchPackage = "builtin_package_rootSearch"
        case scriptCommandsPackage = "builtin_package_scriptCommands"
    }
}

public struct RaycastQuicklinksPackage: Codable, Equatable, Sendable {
    public var quicklinks: [RaycastQuicklinkRecord]?

    public init(quicklinks: [RaycastQuicklinkRecord]? = nil) {
        self.quicklinks = quicklinks
    }
}

public struct RaycastQuicklinkRecord: Codable, Equatable, Sendable {
    public var uuid: String?
    public var name: String?
    public var url: String?
    public var isEnabled: Bool?

    public init(uuid: String? = nil, name: String? = nil, url: String? = nil, isEnabled: Bool? = nil) {
        self.uuid = uuid
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
    }
}

public struct RaycastSnippetsPackage: Codable, Equatable, Sendable {
    public var snippets: [RaycastSnippetRecord]?

    public init(snippets: [RaycastSnippetRecord]? = nil) {
        self.snippets = snippets
    }
}

public struct RaycastSnippetRecord: Codable, Equatable, Sendable {
    public var name: String?
    public var text: String?
    public var keyword: String?
    public var pinned: Bool?

    public init(name: String? = nil, text: String? = nil, keyword: String? = nil, pinned: Bool? = nil) {
        self.name = name
        self.text = text
        self.keyword = keyword
        self.pinned = pinned
    }
}

public struct RaycastNotesPackage: Codable, Equatable, Sendable {
    public var notes: [RaycastNoteRecord]?

    public init(notes: [RaycastNoteRecord]? = nil) {
        self.notes = notes
    }
}

public struct RaycastNoteRecord: Codable, Equatable, Sendable {
    public var title: String?
    public var text: String?
    public var pinned: Bool?

    public init(title: String? = nil, text: String? = nil, pinned: Bool? = nil) {
        self.title = title
        self.text = text
        self.pinned = pinned
    }
}

public struct RaycastExtensionsPackage: Codable, Equatable, Sendable {
    public var extensions: [RaycastExtensionRecord]?

    public init(extensions: [RaycastExtensionRecord]? = nil) {
        self.extensions = extensions
    }
}

public struct RaycastExtensionRecord: Codable, Equatable, Sendable {
    public var name: String?
    public var owner: String?
    public var title: String?
    public var commands: [RaycastExtensionCommandRecord]?
    public var prefs: [RaycastPreferenceRecord]?

    public init(
        name: String? = nil,
        owner: String? = nil,
        title: String? = nil,
        commands: [RaycastExtensionCommandRecord]? = nil,
        prefs: [RaycastPreferenceRecord]? = nil
    ) {
        self.name = name
        self.owner = owner
        self.title = title
        self.commands = commands
        self.prefs = prefs
    }
}

public struct RaycastExtensionCommandRecord: Codable, Equatable, Sendable {
    public var name: String?
    public var enabled: Bool?

    public init(name: String? = nil, enabled: Bool? = nil) {
        self.name = name
        self.enabled = enabled
    }
}

public struct RaycastPreferenceRecord: Codable, Equatable, Sendable {
    public var name: String?
    public var type: String?
    public var value: RaycastJSONValue?
    public var hasValue: Bool

    public init(
        name: String? = nil,
        type: String? = nil,
        value: RaycastJSONValue? = nil,
        hasValue: Bool = true
    ) {
        self.name = name
        self.type = type
        self.value = value
        self.hasValue = hasValue
    }

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        hasValue = container.contains(.value)
        if hasValue {
            value = try container.decodeIfPresent(RaycastJSONValue.self, forKey: .value) ?? .null
        } else {
            value = nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(type, forKey: .type)
        if hasValue {
            try container.encode(value ?? .null, forKey: .value)
        }
    }
}

public enum RaycastJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: RaycastJSONValue])
    case array([RaycastJSONValue])
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: RaycastJSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([RaycastJSONValue].self) { self = .array(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

public struct RaycastPreferencesPackage: Codable, Equatable, Sendable {
    public var preferencesGeneral: RaycastGeneralPreferences?
    public var preferencesAppearance: RaycastAppearancePreferences?
    public var preferencesAdvanced: RaycastAdvancedPreferences?

    public init(
        preferencesGeneral: RaycastGeneralPreferences? = nil,
        preferencesAppearance: RaycastAppearancePreferences? = nil,
        preferencesAdvanced: RaycastAdvancedPreferences? = nil
    ) {
        self.preferencesGeneral = preferencesGeneral
        self.preferencesAppearance = preferencesAppearance
        self.preferencesAdvanced = preferencesAdvanced
    }
}

public struct RaycastGeneralPreferences: Codable, Equatable, Sendable {
    public var raycastGlobalHotkey: String?

    public init(raycastGlobalHotkey: String? = nil) {
        self.raycastGlobalHotkey = raycastGlobalHotkey
    }
}

public struct RaycastAppearancePreferences: Codable, Equatable, Sendable {
    public var raycastPreferredWindowMode: String?

    public init(raycastPreferredWindowMode: String? = nil) {
        self.raycastPreferredWindowMode = raycastPreferredWindowMode
    }
}

public struct RaycastAdvancedPreferences: Codable, Equatable, Sendable {
    public var navigationCommandStyleIdentifierKey: String?
    public var popToRootTimeout: Double?

    public init(navigationCommandStyleIdentifierKey: String? = nil, popToRootTimeout: Double? = nil) {
        self.navigationCommandStyleIdentifierKey = navigationCommandStyleIdentifierKey
        self.popToRootTimeout = popToRootTimeout
    }
}

public struct RaycastRootSearchPackage: Codable, Equatable, Sendable {
    public var rootSearch: [RaycastRootSearchRecord]?

    public init(rootSearch: [RaycastRootSearchRecord]? = nil) {
        self.rootSearch = rootSearch
    }
}

public struct RaycastRootSearchRecord: Codable, Equatable, Sendable {
    public var key: String?
    public var type: String?
    public var path: String?
    public var hotkey: String?
    public var searchTerms: String?

    public init(key: String? = nil, type: String? = nil, path: String? = nil, hotkey: String? = nil, searchTerms: String? = nil) {
        self.key = key
        self.type = type
        self.path = path
        self.hotkey = hotkey
        self.searchTerms = searchTerms
    }
}

public struct RaycastScriptCommandsPackage: Codable, Equatable, Sendable {
    public var scriptCommandsDirectories: [String]?
    public var disabledCommands: [String]?

    public init(scriptCommandsDirectories: [String]? = nil, disabledCommands: [String]? = nil) {
        self.scriptCommandsDirectories = scriptCommandsDirectories
        self.disabledCommands = disabledCommands
    }
}
