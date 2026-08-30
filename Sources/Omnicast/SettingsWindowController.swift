// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import OmnicastCore
import OmnicastUI
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(store: SettingsStore) {
        let view = SettingsView(store: store, onHotkeyChange: { _ in })
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Omnicast Settings"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
