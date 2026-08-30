// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let item: NSStatusItem
    private let onOpen: () -> Void
    private let onSettings: () -> Void

    init(onOpen: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onSettings = onSettings
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        item.button?.image = NSImage(
            systemSymbolName: "sparkles.rectangle.stack",
            accessibilityDescription: "Omnicast"
        )

        let menu = NSMenu()
        let open = NSMenuItem(title: "Open", action: #selector(openLauncher), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let settings = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
    }

    @objc private func openLauncher() {
        onOpen()
    }

    @objc private func openSettings() {
        onSettings()
    }

    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}
