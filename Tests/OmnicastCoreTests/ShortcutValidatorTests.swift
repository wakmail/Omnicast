// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class ShortcutValidatorTests: XCTestCase {
    func testRejectsBareModifiers() {
        let result = ShortcutValidator.validate(
            keyCode: nil,
            modifiers: ShortcutValidator.optionModifier
        )

        XCTAssertEqual(
            result,
            .rejected("A shortcut needs a key in addition to its modifiers.")
        )
    }

    func testRejectsBareLetter() {
        let result = ShortcutValidator.validate(keyCode: 0, modifiers: 0)

        XCTAssertEqual(result, .rejected("Add a modifier when using a letter."))
    }

    func testAcceptsLetterWithModifier() {
        let result = ShortcutValidator.validate(
            keyCode: 0,
            modifiers: ShortcutValidator.commandModifier
        )

        XCTAssertEqual(result, .accepted)
    }

    func testAcceptsNonletterWithoutModifier() {
        XCTAssertEqual(ShortcutValidator.validate(keyCode: 122, modifiers: 0), .accepted)
    }
}
