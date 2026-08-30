// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine
import OmnicastCore
import OmnicastUI
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: LauncherPanel?
    private var hotkeyManager: HotkeyManager?
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var settingsStore: SettingsStore?
    private var settingsSubscription: AnyCancellable?
    private let keyEvents = LauncherKeyEvents()
    private let toastCenter = ToastCenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            let settingsStore = try SettingsStore()
            let frecencyStore = try FrecencyStore()
            self.settingsStore = settingsStore

            let registry = CommandRegistry(providers: [
                ApplicationsProvider(),
                SystemCommandsProvider()
            ])
            let context = CommandContext(
                clipboard: SystemClipboardService(),
                opener: WorkspaceOpenerService(),
                toasts: toastCenter
            )

            let panel = LauncherPanel(keyEvents: keyEvents)
            let launcherView = LauncherView(
                registry: registry,
                context: context,
                frecencyStore: frecencyStore,
                keyEvents: keyEvents,
                toasts: toastCenter,
                onHide: { [weak panel] returnFocus in
                    panel?.hide(returningFocus: returnFocus)
                },
                onOpenSettings: { [weak self] in
                    self?.showSettings()
                }
            )
            let hostingView = NSHostingView(rootView: launcherView)
            hostingView.wantsLayer = true
            hostingView.layer?.cornerRadius = 16
            hostingView.layer?.masksToBounds = true
            panel.contentView = hostingView
            self.panel = panel

            let hotkeyManager = HotkeyManager { [weak self] in
                self?.toggleLauncher()
            }
            try hotkeyManager.register(settingsStore.settings.hotkey)
            self.hotkeyManager = hotkeyManager

            statusBarController = StatusBarController(
                onOpen: { [weak self] in self?.showLauncher() },
                onSettings: { [weak self] in self?.showSettings() }
            )

            applyTheme(settingsStore.settings.theme)
            settingsSubscription = settingsStore.$settings
                .dropFirst()
                .sink { [weak self] settings in
                    guard let self else { return }
                    self.applyTheme(settings.theme)
                    do {
                        try self.hotkeyManager?.register(settings.hotkey)
                    } catch {
                        self.toastCenter.show(error.localizedDescription)
                    }
                }
        } catch {
            presentStartupError(error)
        }
    }

    private func toggleLauncher() {
        if panel?.isVisible == true {
            panel?.hide(returningFocus: true)
        } else {
            showLauncher()
        }
    }

    private func showLauncher() {
        settingsWindowController?.close()
        panel?.showNearTop()
    }

    private func showSettings() {
        panel?.hide(returningFocus: false)
        guard let settingsStore else { return }
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(store: settingsStore)
        }
        settingsWindowController?.show()
    }

    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func presentStartupError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Omnicast could not start"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        NSApp.terminate(nil)
    }
}
