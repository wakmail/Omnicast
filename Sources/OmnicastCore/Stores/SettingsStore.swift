// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import ServiceManagement

public enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

public enum LauncherWindowMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case compact

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: "Standard"
        case .compact: "Compact"
        }
    }
}

public enum LauncherNavigationStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case vim
    case macOS = "macos"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .vim: "Vim"
        case .macOS: "macOS"
        }
    }
}

public enum SpeechEngineChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case elevenLabs

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: "System Voice"
        case .elevenLabs: "ElevenLabs"
        }
    }
}

public struct HotkeySettings: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var displayName: String

    public init(keyCode: UInt32, modifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    public static let optionSpace = HotkeySettings(
        keyCode: 49,
        modifiers: 2_048,
        displayName: "Option Space"
    )

    public static let controlSpace = HotkeySettings(
        keyCode: 49,
        modifiers: 4_096,
        displayName: "Control Space"
    )

    public static let commandSpace = HotkeySettings(
        keyCode: 49,
        modifiers: 256,
        displayName: "Command Space"
    )

    public static let presets = [optionSpace, controlSpace, commandSpace]
}

public enum ShortcutValidationResult: Equatable, Sendable {
    case accepted
    case rejected(String)
}

public enum ShortcutValidator {
    public static let commandModifier: UInt32 = 256
    public static let shiftModifier: UInt32 = 512
    public static let optionModifier: UInt32 = 2_048
    public static let controlModifier: UInt32 = 4_096

    public static let supportedModifiers = commandModifier
        | shiftModifier
        | optionModifier
        | controlModifier

    public static func validate(
        keyCode: UInt32?,
        modifiers: UInt32
    ) -> ShortcutValidationResult {
        guard let keyCode else {
            return .rejected("A shortcut needs a key in addition to its modifiers.")
        }
        if isLetterKey(keyCode), modifiers & supportedModifiers == 0 {
            return .rejected("Add a modifier when using a letter.")
        }
        return .accepted
    }

    private static func isLetterKey(_ keyCode: UInt32) -> Bool {
        letterKeyCodes.contains(keyCode)
    }

    private static let letterKeyCodes: Set<UInt32> = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
        11, 12, 13, 14, 15, 16, 17, 31, 32,
        34, 35, 37, 38, 40, 45, 46
    ]
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var hotkey: HotkeySettings
    public var theme: AppTheme
    public var launchAtLogin: Bool
    public var hyperKey: HyperKeySettings
    public var snippetsEnabled: Bool
    public var dictationEnabled: Bool
    public var launcherPosition: LauncherWindowPosition?
    public var hasShownOnboarding: Bool
    public var defaultAIProvider: AIProviderIdentifier
    public var defaultAIModel: String
    public var openAICompatibleEnabled: Bool
    public var openAICompatibleBaseURL: String
    public var speechEngine: SpeechEngineChoice
    public var systemSpeechVoiceIdentifier: String
    public var systemSpeechRate: Double
    public var elevenLabsVoiceIdentifier: String
    public var windowMode: LauncherWindowMode
    public var popToRootTimeout: Double
    public var navigationStyle: LauncherNavigationStyle

    public init(
        hotkey: HotkeySettings = .optionSpace,
        theme: AppTheme = .system,
        launchAtLogin: Bool = false,
        hyperKey: HyperKeySettings = HyperKeySettings(),
        snippetsEnabled: Bool = false,
        dictationEnabled: Bool = false,
        launcherPosition: LauncherWindowPosition? = nil,
        hasShownOnboarding: Bool = false,
        defaultAIProvider: AIProviderIdentifier = .openAI,
        defaultAIModel: String = "gpt-4o-mini",
        openAICompatibleEnabled: Bool = false,
        openAICompatibleBaseURL: String = "",
        speechEngine: SpeechEngineChoice = .system,
        systemSpeechVoiceIdentifier: String = "",
        systemSpeechRate: Double = 0.5,
        elevenLabsVoiceIdentifier: String = "21m00Tcm4TlvDq8ikWAM",
        windowMode: LauncherWindowMode = .standard,
        popToRootTimeout: Double = 90,
        navigationStyle: LauncherNavigationStyle = .vim
    ) {
        self.hotkey = hotkey
        self.theme = theme
        self.launchAtLogin = launchAtLogin
        self.hyperKey = hyperKey
        self.snippetsEnabled = snippetsEnabled
        self.dictationEnabled = dictationEnabled
        self.launcherPosition = launcherPosition
        self.hasShownOnboarding = hasShownOnboarding
        self.defaultAIProvider = defaultAIProvider
        self.defaultAIModel = defaultAIModel
        self.openAICompatibleEnabled = openAICompatibleEnabled
        self.openAICompatibleBaseURL = openAICompatibleBaseURL
        self.speechEngine = speechEngine
        self.systemSpeechVoiceIdentifier = systemSpeechVoiceIdentifier
        self.systemSpeechRate = systemSpeechRate
        self.elevenLabsVoiceIdentifier = elevenLabsVoiceIdentifier
        self.windowMode = windowMode
        self.popToRootTimeout = popToRootTimeout
        self.navigationStyle = navigationStyle
    }

    private enum CodingKeys: String, CodingKey {
        case hotkey
        case theme
        case launchAtLogin
        case hyperKey
        case snippetsEnabled
        case dictationEnabled
        case launcherPosition
        case hasShownOnboarding
        case defaultAIProvider
        case defaultAIModel
        case openAICompatibleEnabled
        case openAICompatibleBaseURL
        case speechEngine
        case systemSpeechVoiceIdentifier
        case systemSpeechRate
        case elevenLabsVoiceIdentifier
        case windowMode
        case popToRootTimeout
        case navigationStyle
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hotkey = try values.decodeIfPresent(HotkeySettings.self, forKey: .hotkey) ?? .optionSpace
        theme = try values.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        launchAtLogin = try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        hyperKey = try values.decodeIfPresent(HyperKeySettings.self, forKey: .hyperKey)
            ?? HyperKeySettings()
        snippetsEnabled = try values.decodeIfPresent(Bool.self, forKey: .snippetsEnabled) ?? false
        dictationEnabled = try values.decodeIfPresent(Bool.self, forKey: .dictationEnabled) ?? false
        launcherPosition = try values.decodeIfPresent(
            LauncherWindowPosition.self,
            forKey: .launcherPosition
        )
        hasShownOnboarding = try values.decodeIfPresent(Bool.self, forKey: .hasShownOnboarding)
            ?? false
        defaultAIProvider = try values.decodeIfPresent(
            AIProviderIdentifier.self,
            forKey: .defaultAIProvider
        ) ?? .openAI
        defaultAIModel = try values.decodeIfPresent(String.self, forKey: .defaultAIModel)
            ?? "gpt-4o-mini"
        openAICompatibleEnabled = try values.decodeIfPresent(
            Bool.self,
            forKey: .openAICompatibleEnabled
        ) ?? false
        openAICompatibleBaseURL = try values.decodeIfPresent(
            String.self,
            forKey: .openAICompatibleBaseURL
        ) ?? ""
        speechEngine = try values.decodeIfPresent(
            SpeechEngineChoice.self,
            forKey: .speechEngine
        ) ?? .system
        systemSpeechVoiceIdentifier = try values.decodeIfPresent(
            String.self,
            forKey: .systemSpeechVoiceIdentifier
        ) ?? ""
        systemSpeechRate = try values.decodeIfPresent(
            Double.self,
            forKey: .systemSpeechRate
        ) ?? 0.5
        elevenLabsVoiceIdentifier = try values.decodeIfPresent(
            String.self,
            forKey: .elevenLabsVoiceIdentifier
        ) ?? "21m00Tcm4TlvDq8ikWAM"
        windowMode = try values.decodeIfPresent(
            LauncherWindowMode.self,
            forKey: .windowMode
        ) ?? .standard
        popToRootTimeout = try values.decodeIfPresent(
            Double.self,
            forKey: .popToRootTimeout
        ) ?? 90
        navigationStyle = try values.decodeIfPresent(
            LauncherNavigationStyle.self,
            forKey: .navigationStyle
        ) ?? .vim
    }
}

public struct LauncherWindowPosition: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

@MainActor
public final class SettingsStore: ObservableObject {
    @Published public private(set) var settings: AppSettings
    public let fileURL: URL

    public init(directoryURL: URL = OmnicastDataDirectory.defaultURL) throws {
        fileURL = directoryURL.appendingPathComponent("settings.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            settings = try JSONDecoder().decode(AppSettings.self, from: data)
        } else {
            settings = AppSettings()
        }
    }

    public func update(_ change: (inout AppSettings) -> Void) throws {
        var next = settings
        change(&next)
        settings = next
        try save()
    }

    public func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
        try update { $0.launchAtLogin = enabled }
    }

    public func refreshLaunchAtLoginStatus() throws {
        let enabled = SMAppService.mainApp.status == .enabled
        if settings.launchAtLogin != enabled {
            try update { $0.launchAtLogin = enabled }
        }
    }

    private func save() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: fileURL, options: .atomic)
    }
}

public enum OmnicastDataDirectory {
    public static var defaultURL: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Omnicast", isDirectory: true)
    }
}
