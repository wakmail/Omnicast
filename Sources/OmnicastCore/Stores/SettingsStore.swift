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

    public init(
        hotkey: HotkeySettings = .optionSpace,
        theme: AppTheme = .system,
        launchAtLogin: Bool = false
    ) {
        self.hotkey = hotkey
        self.theme = theme
        self.launchAtLogin = launchAtLogin
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
