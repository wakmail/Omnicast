// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testRoundTrip() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SettingsStore(directoryURL: directory)
        try store.update { settings in
            settings.hotkey = .controlSpace
            settings.theme = .dark
            settings.launchAtLogin = true
            settings.hyperKey = HyperKeySettings(
                tapAction: .keyboardShortcut(keyCode: 45, modifiers: 1_310_720),
                enabled: true
            )
            settings.snippetsEnabled = true
            settings.dictationEnabled = true
            settings.launcherPosition = LauncherWindowPosition(x: 120, y: 340)
            settings.hasShownOnboarding = true
            settings.defaultAIProvider = .anthropic
            settings.defaultAIModel = "claude-sonnet"
            settings.openAICompatibleEnabled = true
            settings.openAICompatibleBaseURL = "https://example.com/v1"
            settings.speechEngine = .elevenLabs
            settings.systemSpeechVoiceIdentifier = "com.apple.voice.compact.en-US.Samantha"
            settings.systemSpeechRate = 0.42
            settings.elevenLabsVoiceIdentifier = "customVoice"
        }

        let loaded = try SettingsStore(directoryURL: directory)
        XCTAssertEqual(loaded.settings, store.settings)
    }

    func testLoadsSettingsWrittenBeforeIntegrationFieldsExisted() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = try JSONSerialization.data(withJSONObject: [
            "hotkey": [
                "keyCode": 49,
                "modifiers": 2_048,
                "displayName": "Option Space"
            ],
            "theme": "System",
            "launchAtLogin": false
        ])
        try data.write(to: directory.appendingPathComponent("settings.json"))

        let loaded = try SettingsStore(directoryURL: directory)

        XCTAssertEqual(loaded.settings.hyperKey, HyperKeySettings())
        XCTAssertFalse(loaded.settings.snippetsEnabled)
        XCTAssertFalse(loaded.settings.dictationEnabled)
        XCTAssertNil(loaded.settings.launcherPosition)
        XCTAssertFalse(loaded.settings.hasShownOnboarding)
        XCTAssertEqual(loaded.settings.defaultAIProvider, .openAI)
        XCTAssertEqual(loaded.settings.speechEngine, .system)
        XCTAssertEqual(loaded.settings.systemSpeechRate, 0.5)
    }
}
