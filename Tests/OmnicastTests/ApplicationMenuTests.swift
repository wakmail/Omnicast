// SPDX-License-Identifier: GPL-3.0-or-later

@testable import Omnicast
import AppKit
import XCTest

@MainActor
final class ApplicationMenuTests: XCTestCase {
    func testEditMenuProvidesStandardFirstResponderActions() throws {
        let application = NSApplication.shared
        let previousMenu = application.mainMenu
        defer { application.mainMenu = previousMenu }

        ApplicationMenu.install(on: application)

        let editMenu = try XCTUnwrap(application.mainMenu?.items.first?.submenu)
        assertItem(editMenu, title: "Undo", action: "undo:", key: "z")
        assertItem(
            editMenu,
            title: "Redo",
            action: "redo:",
            key: "z",
            modifiers: [.command, .shift]
        )
        assertItem(editMenu, title: "Cut", action: "cut:", key: "x")
        assertItem(editMenu, title: "Copy", action: "copy:", key: "c")
        assertItem(editMenu, title: "Paste", action: "paste:", key: "v")
        assertItem(editMenu, title: "Select All", action: "selectAll:", key: "a")
    }

    private func assertItem(
        _ menu: NSMenu,
        title: String,
        action: String,
        key: String,
        modifiers: NSEvent.ModifierFlags = .command,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let item = menu.items.first { $0.title == title }
        XCTAssertEqual(item?.action, Selector((action)), file: file, line: line)
        XCTAssertEqual(item?.keyEquivalent, key, file: file, line: line)
        XCTAssertEqual(item?.keyEquivalentModifierMask, modifiers, file: file, line: line)
        XCTAssertNil(item?.target, file: file, line: line)
    }
}
