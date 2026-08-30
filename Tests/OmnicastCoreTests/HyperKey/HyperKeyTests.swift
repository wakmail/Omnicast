// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import Foundation
@testable import OmnicastCore
import XCTest

final class HyperKeyTests: XCTestCase {
    func testSettingsRoundTrip() throws {
        let actions: [HyperKeyTapAction] = [
            .none,
            .escape,
            .openOmnicast,
            .keyboardShortcut(keyCode: 11, modifiers: 1_310_720),
            .openApplication(bundleIdentifier: "com.apple.Safari"),
            .toggleCapsLock
        ]

        for (index, action) in actions.enumerated() {
            let sourceKey = HyperKeySourceKey.allCases[index % HyperKeySourceKey.allCases.count]
            let settings = HyperKeySettings(
                tapAction: action,
                enabled: true,
                sourceKey: sourceKey
            )
            let data = try JSONEncoder().encode(settings)
            XCTAssertEqual(
                try JSONDecoder().decode(HyperKeySettings.self, from: data),
                settings
            )
        }
    }

    func testLegacyModesDecodeAsTapActions() throws {
        let actionsByMode: [(String, HyperKeyTapAction)] = [
            ("nothing", .none),
            ("escape", .escape),
            ("toggle", .toggleCapsLock)
        ]

        for (mode, action) in actionsByMode {
            let data = try XCTUnwrap("{\"mode\":\"\(mode)\",\"enabled\":true}".data(using: .utf8))
            let settings = try JSONDecoder().decode(HyperKeySettings.self, from: data)
            XCTAssertEqual(settings, HyperKeySettings(tapAction: action, enabled: true))
        }
    }

    func testMissingLegacyModeUsesMigrationDefault() throws {
        let data = try XCTUnwrap("{\"enabled\":true}".data(using: .utf8))
        XCTAssertEqual(
            try JSONDecoder().decode(HyperKeySettings.self, from: data),
            HyperKeySettings(tapAction: .none, enabled: true)
        )
    }

    func testSettingsWithoutSourceKeyMigrateToCapsLock() throws {
        let data = try XCTUnwrap(
            "{\"tapAction\":{\"type\":\"escape\"},\"enabled\":true}".data(using: .utf8)
        )

        XCTAssertEqual(
            try JSONDecoder().decode(HyperKeySettings.self, from: data),
            HyperKeySettings(tapAction: .escape, enabled: true, sourceKey: .capsLock)
        )
    }

    func testDefaultSettingsAreDisabledWithNothingMode() {
        XCTAssertEqual(HyperKeySettings(), HyperKeySettings(tapAction: .none, enabled: false))
    }

    func testTapPostsConfiguredShortcutOnRelease() {
        var postedEvents: [(CGKeyCode, CGEventFlags)] = []
        let state = HyperKeyTapStateMachine(
            action: .keyboardShortcut(keyCode: 12, modifiers: CGEventFlags.maskCommand.rawValue),
            eventPoster: { postedEvents.append(($0, $1)) }
        )

        state.beginSourcePress()
        XCTAssertTrue(postedEvents.isEmpty)
        state.endSourcePress()

        XCTAssertEqual(postedEvents.count, 1)
        XCTAssertEqual(postedEvents.first?.0, 12)
        XCTAssertEqual(postedEvents.first?.1, .maskCommand)
    }

    func testComboSuppressesTapAction() {
        var postedKeyCodes: [CGKeyCode] = []
        let state = HyperKeyTapStateMachine(
            action: .escape,
            eventPoster: { keyCode, _ in postedKeyCodes.append(keyCode) }
        )

        state.beginSourcePress()
        state.markComboFired()
        state.endSourcePress()

        XCTAssertTrue(postedKeyCodes.isEmpty)
    }

    func testNaturalCapsLockTapPostsCapsLockKey() {
        var postedKeyCodes: [CGKeyCode] = []
        let state = HyperKeyTapStateMachine(
            action: .toggleCapsLock,
            eventPoster: { keyCode, _ in postedKeyCodes.append(keyCode) }
        )

        state.beginSourcePress()
        state.endSourcePress()

        XCTAssertEqual(postedKeyCodes, [57])
    }

    func testTapRoutesCallbackActions() {
        var openedOmnicast = false
        var launchedBundleIdentifier: String?
        let omnicastState = HyperKeyTapStateMachine(
            action: .openOmnicast,
            eventPoster: { _, _ in },
            openOmnicast: { openedOmnicast = true }
        )
        let applicationState = HyperKeyTapStateMachine(
            action: .openApplication(bundleIdentifier: "com.apple.TextEdit"),
            eventPoster: { _, _ in },
            applicationLauncher: { launchedBundleIdentifier = $0 }
        )

        omnicastState.beginSourcePress()
        omnicastState.endSourcePress()
        applicationState.beginSourcePress()
        applicationState.endSourcePress()

        XCTAssertTrue(openedOmnicast)
        XCTAssertEqual(launchedBundleIdentifier, "com.apple.TextEdit")
    }

    func testMappingParserPreservesExistingEntries() {
        let output = """
        UserKeyMapping = (\n
            {\n
                HIDKeyboardModifierMappingSrc = 30064771113;\n
                HIDKeyboardModifierMappingDst = 30064771176;\n
            },\n
            {\n
                HIDKeyboardModifierMappingSrc = 30064771129;\n
                HIDKeyboardModifierMappingDst = 30064771181;\n
            }\n
        )
        """
        XCTAssertEqual(
            HyperKeyMappingCodec.parse(output),
            [
                HyperKeyMapping(source: 30_064_771_113, destination: 30_064_771_176),
                HyperKeyMapping(source: 30_064_771_129, destination: 30_064_771_181)
            ]
        )
    }

    func testMappingJSONContainsExpectedHIDValues() throws {
        let mapping = HyperKeyMapping(
            source: HyperKeyMappingCodec.capsLockUsage,
            destination: HyperKeyMappingCodec.function18Usage
        )
        let data = try XCTUnwrap(try HyperKeyMappingCodec.propertyJSON(for: [mapping]).data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let mappings = try XCTUnwrap(object["UserKeyMapping"] as? [[String: NSNumber]])
        XCTAssertEqual(mappings.first?["HIDKeyboardModifierMappingSrc"]?.uint64Value, mapping.source)
        XCTAssertEqual(mappings.first?["HIDKeyboardModifierMappingDst"]?.uint64Value, mapping.destination)
    }

    func testMappingPropertyGenerationForEverySourceKey() throws {
        let expectedUsages: [HyperKeySourceKey: UInt64] = [
            .capsLock: 0x700000039,
            .rightCommand: 0x7000000E7,
            .rightOption: 0x7000000E6,
            .rightControl: 0x7000000E4,
            .fn: 0xFF00000003
        ]
        let preserved = HyperKeyMapping(source: 0x700000004, destination: 0x700000005)

        for sourceKey in HyperKeySourceKey.allCases {
            let generated = HyperKeyMappingCodec.mappings(
                sourceKey: sourceKey,
                target: .function18,
                preserving: [preserved]
            )
            let data = try XCTUnwrap(
                try HyperKeyMappingCodec.propertyJSON(for: generated).data(using: .utf8)
            )
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let mappings = try XCTUnwrap(object["UserKeyMapping"] as? [[String: NSNumber]])

            XCTAssertEqual(mappings.count, 2)
            XCTAssertEqual(
                mappings.last?["HIDKeyboardModifierMappingSrc"]?.uint64Value,
                expectedUsages[sourceKey]
            )
            XCTAssertEqual(
                mappings.last?["HIDKeyboardModifierMappingDst"]?.uint64Value,
                HyperKeyMappingCodec.function18Usage
            )
        }
    }
}
