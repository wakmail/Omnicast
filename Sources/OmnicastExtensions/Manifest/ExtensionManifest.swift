// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public var foundationValue: Any {
        switch self {
        case .string(let value): value
        case .number(let value): value
        case .bool(let value): value
        case .object(let value): value.mapValues(\.foundationValue)
        case .array(let value): value.map(\.foundationValue)
        case .null: NSNull()
        }
    }
}

public struct ExtensionAuthor: Codable, Equatable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let name = try? container.decode(String.self) {
            self.name = name
            return
        }
        let value = try container.decode([String: JSONValue].self)
        guard case .string(let name) = value["name"] else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Author requires a name"
            )
        }
        self.name = name
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}

public struct ExtensionPreferenceOption: Codable, Equatable, Sendable {
    public let title: String?
    public let value: String?

    public init(title: String? = nil, value: String? = nil) {
        self.title = title
        self.value = value
    }
}

public struct ExtensionPreference: Codable, Equatable, Sendable {
    public let name: String
    public let type: String
    public let title: String?
    public let label: String?
    public let description: String?
    public let placeholder: String?
    public let required: Bool
    public let defaultValue: JSONValue?
    public let data: [ExtensionPreferenceOption]

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case title
        case label
        case description
        case placeholder
        case required
        case defaultValue = "default"
        case data
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "textfield"
        title = try container.decodeIfPresent(String.self, forKey: .title)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        defaultValue = try container.decodeIfPresent(JSONValue.self, forKey: .defaultValue)
        data = try container.decodeIfPresent([ExtensionPreferenceOption].self, forKey: .data) ?? []
    }

    public init(
        name: String,
        type: String,
        title: String? = nil,
        label: String? = nil,
        description: String? = nil,
        placeholder: String? = nil,
        required: Bool = false,
        defaultValue: JSONValue? = nil,
        data: [ExtensionPreferenceOption] = []
    ) {
        self.name = name
        self.type = type
        self.title = title
        self.label = label
        self.description = description
        self.placeholder = placeholder
        self.required = required
        self.defaultValue = defaultValue
        self.data = data
    }
}

public struct ExtensionCommandArgument: Codable, Equatable, Sendable {
    public let name: String
    public let type: String?
    public let title: String?
    public let placeholder: String?
    public let required: Bool
    public let data: [ExtensionPreferenceOption]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        data = try container.decodeIfPresent([ExtensionPreferenceOption].self, forKey: .data) ?? []
    }
}

public struct ExtensionCommandManifest: Codable, Equatable, Sendable {
    public let name: String
    public let title: String
    public let description: String
    public let mode: String
    public let icon: String?
    public let source: String?
    public let interval: String?
    public let disabledByDefault: Bool
    public let preferences: [ExtensionPreference]
    public let arguments: [ExtensionCommandArgument]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? name
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "view"
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        interval = try container.decodeIfPresent(String.self, forKey: .interval)
        disabledByDefault = try container.decodeIfPresent(Bool.self, forKey: .disabledByDefault) ?? false
        preferences = try container.decodeIfPresent([ExtensionPreference].self, forKey: .preferences) ?? []
        arguments = try container.decodeIfPresent([ExtensionCommandArgument].self, forKey: .arguments) ?? []
    }
}

public struct ExtensionManifest: Codable, Equatable, Sendable {
    public let name: String
    public let title: String
    public let description: String
    public let version: String?
    public let icon: String?
    public let owner: ExtensionAuthor?
    public let author: ExtensionAuthor?
    public let commands: [ExtensionCommandManifest]
    public let preferences: [ExtensionPreference]
    public let platforms: [String]
    public let categories: [String]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? name
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        version = try container.decodeIfPresent(String.self, forKey: .version)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        owner = try container.decodeIfPresent(ExtensionAuthor.self, forKey: .owner)
        author = try container.decodeIfPresent(ExtensionAuthor.self, forKey: .author)
        commands = try container.decodeIfPresent([ExtensionCommandManifest].self, forKey: .commands) ?? []
        preferences = try container.decodeIfPresent([ExtensionPreference].self, forKey: .preferences) ?? []
        platforms = try container.decodeIfPresent([String].self, forKey: .platforms) ?? []
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
    }

    public static func decode(from data: Data) throws -> ExtensionManifest {
        try JSONDecoder().decode(ExtensionManifest.self, from: data)
    }
}
