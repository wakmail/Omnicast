// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

@MainActor
enum ApplicationMenu {
    static func install(on application: NSApplication) {
        let mainMenu = NSMenu()
        let editMenu = NSMenu(title: "Edit")

        editMenu.addItem(item("Undo", action: "undo:", key: "z"))
        editMenu.addItem(item(
            "Redo",
            action: "redo:",
            key: "z",
            modifiers: [.command, .shift]
        ))
        editMenu.addItem(.separator())
        editMenu.addItem(item("Cut", action: "cut:", key: "x"))
        editMenu.addItem(item("Copy", action: "copy:", key: "c"))
        editMenu.addItem(item("Paste", action: "paste:", key: "v"))
        editMenu.addItem(item("Select All", action: "selectAll:", key: "a"))

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        application.mainMenu = mainMenu
    }

    private static func item(
        _ title: String,
        action: String,
        key: String,
        modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: Selector((action)),
            keyEquivalent: key
        )
        item.keyEquivalentModifierMask = modifiers
        return item
    }
}
