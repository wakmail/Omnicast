// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class MenuItemIndexTests: XCTestCase {
    func testFlattensInjectedMenuFixture() {
        let fixture = [
            MenuElementFixture(title: "Apple", children: [
                MenuElementFixture(title: "About")
            ]),
            MenuElementFixture(title: "File", children: [
                MenuElementFixture(title: "", children: [
                    MenuElementFixture(title: "New Window", shortcut: "⌘N"),
                    MenuElementFixture(title: ""),
                    MenuElementFixture(title: "Close", shortcut: "⌘W", isEnabled: false)
                ])
            ])
        ]

        let items = MenuItemTreeFlattener.flatten(fixture)

        XCTAssertEqual(items.map(\.fullPath), ["File > New Window", "File > Close"])
        XCTAssertEqual(items.map(\.path), ["File", "File"])
        XCTAssertEqual(items.map(\.shortcut), ["⌘N", "⌘W"])
        XCTAssertEqual(items.map(\.isEnabled), [true, false])
    }

    func testMapsAccessibilityShortcutModifiersAndCharacters() {
        XCTAssertEqual(MenuItemIndex.modifierString(0), "⌘")
        XCTAssertEqual(MenuItemIndex.modifierString(7), "⌃⌥⇧⌘")
        XCTAssertEqual(MenuItemIndex.modifierString(8), "")
        XCTAssertEqual(MenuItemIndex.shortcutCharacter("\u{F700}"), "↑")
        XCTAssertEqual(MenuItemIndex.shortcutCharacter("n"), "N")
        XCTAssertEqual(MenuItemIndex.virtualKeyString(122), "F1")
        XCTAssertNil(MenuItemIndex.virtualKeyString(999))
    }
}
