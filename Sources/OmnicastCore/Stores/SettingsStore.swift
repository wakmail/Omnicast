// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import ServiceManagement

public enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
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

public struct AppSettings: Codable, Equatable, Sendable {
    public var hotkey: HotkeySettings
    public var theme: AppTheme
    public var launchAtLogin: Bool
    public var hyperKey: HyperKeySettings
    public var snippetsEnabled: Bool
    public var launcherPosition: LauncherWindowPosition?
    public var hasShownOnboarding: Bool
    public var defaultAIProvider: AIProviderIdentifier
    public var defaultAIModel: String
    public var openAICompatibleEnabled: Bool
    public var openAICompatibleBaseURL: String

    public init(
        hotkey: HotkeySettings = .optionSpace,
        theme: AppTheme = .system,
        launchAtLogin: Bool = false,
        hyperKey: HyperKeySettings = HyperKeySettings(),
        snippetsEnabled: Bool = false,
        launcherPosition: LauncherWindowPosition? = nil,
        hasShownOnboarding: Bool = false,
        defaultAIProvider: AIProviderIdentifier = .openAI,
        defaultAIModel: String = "gpt-4o-mini",
        openAICompatibleEnabled: Bool = false,
        openAICompatibleBaseURL: String = ""
    ) {
        self.hotkey = hotkey
        self.theme = theme
        self.launchAtLogin = launchAtLogin
        self.hyperKey = hyperKey
        self.snippetsEnabled = snippetsEnabled
        self.launcherPosition = launcherPosition
        self.hasShownOnboarding = hasShownOnboarding
        self.defaultAIProvider = defaultAIProvider
        self.defaultAIModel = defaultAIModel
        self.openAICompatibleEnabled = openAICompatibleEnabled
        self.openAICompatibleBaseURL = openAICompatibleBaseURL
    }

    private enum CodingKeys: String, CodingKey {
        case hotkey
        case theme
        case launchAtLogin
        case hyperKey
        case snippetsEnabled
        case launcherPosition
        case hasShownOnboarding
        case defaultAIProvider
        case defaultAIModel
        case openAICompatibleEnabled
        case openAICompatibleBaseURL
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hotkey = try values.decodeIfPresent(HotkeySettings.self, forKey: .hotkey) ?? .optionSpace
        theme = try values.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        launchAtLogin = try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        hyperKey = try values.decodeIfPresent(HyperKeySettings.self, forKey: .hyperKey)
            ?? HyperKeySettings()
        snippetsEnabled = try values.decodeIfPresent(Bool.self, forKey: .snippetsEnabled) ?? false
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
