// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import OmnicastCore
import XCTest

final class HyperKeyTests: XCTestCase {
    func testSettingsRoundTrip() throws {
        let settings = HyperKeySettings(mode: .escape, enabled: true)
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(HyperKeySettings.self, from: data), settings)
    }

    func testDefaultSettingsAreDisabledWithNothingMode() {
        XCTAssertEqual(HyperKeySettings(), HyperKeySettings(mode: .nothing, enabled: false))
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
}
