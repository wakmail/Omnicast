// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum HyperKeyMode: String, Codable, CaseIterable, Sendable {
    case escape
    case nothing
    case toggle
}

public enum HyperKeySourceKey: String, Codable, CaseIterable, Sendable {
    case capsLock
    case rightCommand
    case rightOption
    case rightControl
    case fn
}

public enum HyperKeyTapAction: Codable, Equatable, Sendable {
    case none
    case escape
    case openOmnicast
    case keyboardShortcut(keyCode: UInt16, modifiers: UInt64)
    case openApplication(bundleIdentifier: String)
    case toggleCapsLock

    private enum CodingKeys: String, CodingKey {
        case type
        case keyCode
        case modifiers
        case bundleIdentifier
    }

    private enum ActionType: String, Codable {
        case none
        case escape
        case openOmnicast
        case keyboardShortcut
        case openApplication
        case toggleCapsLock
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(ActionType.self, forKey: .type) {
        case .none:
            self = .none
        case .escape:
            self = .escape
        case .openOmnicast:
            self = .openOmnicast
        case .keyboardShortcut:
            self = try .keyboardShortcut(
                keyCode: values.decode(UInt16.self, forKey: .keyCode),
                modifiers: values.decode(UInt64.self, forKey: .modifiers)
            )
        case .openApplication:
            self = try .openApplication(
                bundleIdentifier: values.decode(String.self, forKey: .bundleIdentifier)
            )
        case .toggleCapsLock:
            self = .toggleCapsLock
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try values.encode(ActionType.none, forKey: .type)
        case .escape:
            try values.encode(ActionType.escape, forKey: .type)
        case .openOmnicast:
            try values.encode(ActionType.openOmnicast, forKey: .type)
        case .keyboardShortcut(let keyCode, let modifiers):
            try values.encode(ActionType.keyboardShortcut, forKey: .type)
            try values.encode(keyCode, forKey: .keyCode)
            try values.encode(modifiers, forKey: .modifiers)
        case .openApplication(let bundleIdentifier):
            try values.encode(ActionType.openApplication, forKey: .type)
            try values.encode(bundleIdentifier, forKey: .bundleIdentifier)
        case .toggleCapsLock:
            try values.encode(ActionType.toggleCapsLock, forKey: .type)
        }
    }
}

public struct HyperKeySettings: Codable, Equatable, Sendable {
    public var tapAction: HyperKeyTapAction
    public var enabled: Bool
    public var sourceKey: HyperKeySourceKey

    public init(
        tapAction: HyperKeyTapAction = .none,
        enabled: Bool = false,
        sourceKey: HyperKeySourceKey = .capsLock
    ) {
        self.tapAction = tapAction
        self.enabled = enabled
        self.sourceKey = sourceKey
    }

    public init(
        mode: HyperKeyMode,
        enabled: Bool = false,
        sourceKey: HyperKeySourceKey = .capsLock
    ) {
        tapAction = Self.tapAction(for: mode)
        self.enabled = enabled
        self.sourceKey = sourceKey
    }

    public var mode: HyperKeyMode {
        get {
            switch tapAction {
            case .escape: .escape
            case .toggleCapsLock: .toggle
            default: .nothing
            }
        }
        set { tapAction = Self.tapAction(for: newValue) }
    }

    private enum CodingKeys: String, CodingKey {
        case tapAction
        case mode
        case enabled
        case sourceKey
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        sourceKey = try values.decodeIfPresent(HyperKeySourceKey.self, forKey: .sourceKey)
            ?? .capsLock
        if let action = try values.decodeIfPresent(HyperKeyTapAction.self, forKey: .tapAction) {
            tapAction = action
        } else {
            let legacyMode = try values.decodeIfPresent(HyperKeyMode.self, forKey: .mode) ?? .nothing
            tapAction = Self.tapAction(for: legacyMode)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(tapAction, forKey: .tapAction)
        try values.encode(enabled, forKey: .enabled)
        try values.encode(sourceKey, forKey: .sourceKey)
    }

    private static func tapAction(for mode: HyperKeyMode) -> HyperKeyTapAction {
        switch mode {
        case .escape: .escape
        case .nothing: .none
        case .toggle: .toggleCapsLock
        }
    }
}

public enum HyperKeyRemapTarget: String, Codable, CaseIterable, Sendable {
    case function18
    case rightControl
}
