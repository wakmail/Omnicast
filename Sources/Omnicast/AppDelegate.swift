// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine
import OmnicastCore
import OmnicastExtensions
import OmnicastUI
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: LauncherPanel?
    private var hotkeyManager: HotkeyManager?
    private var hyperKeyManager: HyperKeyManager?
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var snippetWindow: NSWindow?
    private var settingsStore: SettingsStore?
    private var permissions: PermissionsService?
    private var snippetEnableController: PermissionFeatureController?
    private var hyperKeyEnableController: PermissionFeatureController?
    private var dictationEnableController: PermissionFeatureController?
    private var registry: CommandRegistry?
    private var commandContext: CommandContext?

    private var clipboardStore: ClipboardHistoryStore?
    private var clipboardMonitor: ClipboardMonitor?
    private var pasteService: PasteService?
    private var snippetStore: SnippetStore?
    private var snippetExpander: SnippetExpander?
    private var quicklinkStore: QuicklinkStore?
    private var fileSearchIndex: FileSearchIndex?
    private var notesStore: NotesStore?
    private var calendarService: CalendarService?
    private var emojiStore: EmojiStore?
    private var emojiPasteService: EmojiPasteService?
    private var colorHistoryStore: ColorHistoryStore?
    private var menuItemIndex: MenuItemIndex?
    private var calculatorProvider: CalculatorProvider?

    private var dictationPermissions: DictationPermissions?
    private var dictationController: HoldToSpeakController?
    private var dictationHUDPanelController: DictationHUDPanelController?
    private var speechKeyStore: SpeechKeyStore?
    private var speechEngine: SwitchingSpeechEngine?
    private var speechProvider: SpeechCommandsProvider?
    private var appliedSpeechConfiguration: AppliedSpeechConfiguration?

    private var aiKeyStore: AIKeyStore?
    private var aiController: AIWindowController?
    private var appliedHotkeySettings: HotkeySettings?
    private var appliedTheme: AppTheme?

    private var extensionRegistry: ExtensionRegistry?
    private var extensionStoreClient: RaycastStoreClient?
    private var extensionHost: ExtensionHost?

    private let windowAdjuster = WindowAdjuster()
    private let webSearchBangs = WebSearchBangs()
    private let keyEvents = LauncherKeyEvents()
    private let toastCenter = ToastCenter()
    private let navigationCoordinator = LauncherNavigationCoordinator()
    private var subscriptions = Set<AnyCancellable>()
    private var distributedObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            let settingsStore = try SettingsStore()
            let frecencyStore = try FrecencyStore()
            let clipboardStore = try ClipboardHistoryStore()
            let clipboardMonitor = ClipboardMonitor(store: clipboardStore)
            let pasteService = PasteService()
            let snippetStore = try SnippetStore()
            let snippetExpander = SnippetExpander(store: snippetStore)
            let quicklinkStore = try QuicklinkStore()
            let fileSearchIndex = FileSearchIndex()
            let notesStore = try NotesStore(directoryURL: OmnicastDataDirectory.defaultURL)
            let calendarService = CalendarService()
            let emojiStore = try EmojiStore()
            let emojiPasteService = EmojiPasteService()
            let colorHistoryStore = try ColorHistoryStore()
            let menuItemIndex = MenuItemIndex()
            let calculatorProvider = CalculatorProvider()
            let aiKeyStore = AIKeyStore()
            let aiChatStore = try AIChatStore()
            let aiController = AIWindowController(
                keyStore: aiKeyStore,
                chatStore: aiChatStore,
                settings: settingsStore.settings,
                onShow: { [weak self] in self?.panel?.hide(returningFocus: false) }
            )
            let speechKeyStore = SpeechKeyStore()
            let initialSpeechEngine = makeSpeechEngine(
                settings: settingsStore.settings,
                keyStore: speechKeyStore
            )
            let speechEngine = SwitchingSpeechEngine(activeEngine: initialSpeechEngine)
            let speechProvider = SpeechCommandsProvider(engine: speechEngine)
            let extensionStoreClient = RaycastStoreClient()
            let extensionRegistry = ExtensionRegistry(store: extensionStoreClient)
            let dictationPermissions = DictationPermissions()
            let permissions = PermissionsService(dictationPermissions: dictationPermissions)
            if settingsStore.settings.hyperKey.enabled && !permissions.inputMonitoring {
                try settingsStore.update { $0.hyperKey.enabled = false }
            }
            if settingsStore.settings.snippetsEnabled
                && !(permissions.accessibility && permissions.inputMonitoring) {
                try settingsStore.update { $0.snippetsEnabled = false }
            }
            if settingsStore.settings.dictationEnabled && !dictationPermissions.isGranted {
                try settingsStore.update { $0.dictationEnabled = false }
            }
            let hyperKeyManager = HyperKeyManager(
                settings: settingsStore.settings.hyperKey,
                onOpenOmnicast: { [weak self] in self?.toggleLauncher() },
                onOpenApplication: { bundleIdentifier in
                    guard let url = NSWorkspace.shared.urlForApplication(
                        withBundleIdentifier: bundleIdentifier
                    ) else { return }
                    NSWorkspace.shared.openApplication(at: url, configuration: .init())
                }
            )
            let dictationController = HoldToSpeakController(engine: NativeSpeechEngine())
            let dictationHUDPanelController = DictationHUDPanelController(
                controller: dictationController
            )
            let snippetEnableController = PermissionFeatureController(
                feature: .snippets,
                enabled: settingsStore.settings.snippetsEnabled,
                permissions: permissions
            ) { [unowned settingsStore] enabled in
                try settingsStore.update { $0.snippetsEnabled = enabled }
            }
            let hyperKeyEnableController = PermissionFeatureController(
                feature: .hyperKey,
                enabled: settingsStore.settings.hyperKey.enabled,
                permissions: permissions
            ) { [unowned settingsStore] enabled in
                try settingsStore.update { $0.hyperKey.enabled = enabled }
            }
            let dictationEnableController = PermissionFeatureController(
                feature: .dictation,
                enabled: settingsStore.settings.dictationEnabled,
                permissions: permissions
            ) { [unowned settingsStore] enabled in
                try settingsStore.update { $0.dictationEnabled = enabled }
            }

            permissions.onRequest = { [weak permissions] kind in
                guard let permissions else { return }
                PermissionGuideOverlay.shared.show(for: kind, permissions: permissions)
            }

            self.settingsStore = settingsStore
            self.permissions = permissions
            self.snippetEnableController = snippetEnableController
            self.hyperKeyEnableController = hyperKeyEnableController
            self.dictationEnableController = dictationEnableController
            self.clipboardStore = clipboardStore
            self.clipboardMonitor = clipboardMonitor
            self.pasteService = pasteService
            self.snippetStore = snippetStore
            self.snippetExpander = snippetExpander
            self.quicklinkStore = quicklinkStore
            self.fileSearchIndex = fileSearchIndex
            self.notesStore = notesStore
            self.calendarService = calendarService
            self.emojiStore = emojiStore
            self.emojiPasteService = emojiPasteService
            self.colorHistoryStore = colorHistoryStore
            self.menuItemIndex = menuItemIndex
            self.calculatorProvider = calculatorProvider
            self.dictationPermissions = dictationPermissions
            self.dictationController = dictationController
            self.dictationHUDPanelController = dictationHUDPanelController
            self.speechKeyStore = speechKeyStore
            self.speechEngine = speechEngine
            self.speechProvider = speechProvider
            self.appliedSpeechConfiguration = AppliedSpeechConfiguration(
                settings: settingsStore.settings
            )
            self.aiKeyStore = aiKeyStore
            self.aiController = aiController
            self.extensionStoreClient = extensionStoreClient
            self.extensionRegistry = extensionRegistry
            self.hyperKeyManager = hyperKeyManager

            pasteService.didWritePasteboard = { [weak clipboardMonitor] in
                clipboardMonitor?.ignoreCurrentPasteboardContents()
            }
            emojiPasteService.didWritePasteboard = { [weak clipboardMonitor] in
                clipboardMonitor?.ignoreCurrentPasteboardContents()
            }
            dictationController.onError = { [weak self] error in
                self?.toastCenter.show(error.localizedDescription)
            }

            let clipboardService = SystemClipboardService()
            let opener = WorkspaceOpenerService()
            let context = CommandContext(
                clipboard: clipboardService,
                opener: opener,
                toasts: toastCenter
            )
            commandContext = context

            let raycastImportStore = try RaycastImportStore()
            let raycastImporter = try RaycastImporter(
                quicklinkStore: quicklinkStore,
                snippetStore: snippetStore,
                notesStore: notesStore,
                settingsStore: settingsStore,
                importStore: raycastImportStore
            )

            let registry = CommandRegistry(providers: [
                ApplicationsProvider(),
                RaycastImportCommandProvider(),
                SystemCommandsProvider(),
                ResetWindowPositionProvider { [weak self] in
                    self?.resetWindowPosition()
                },
                ClipboardCommandsProvider(),
                FileSearchProvider(),
                ScriptCommandsProvider(),
                QuicklinkCommandsProvider(),
                SnippetCommandsProvider(store: snippetStore) { [weak self] in
                    self?.showSnippetManager()
                },
                NotesCommandsProvider(store: notesStore),
                CalendarCommandsProvider(),
                EmojiCommandsProvider(),
                ColorPickerCommandsProvider(store: colorHistoryStore),
                MenuSearchCommandsProvider(),
                speechProvider,
                WindowCommandsProvider(
                    adjuster: windowAdjuster,
                    requestAccessibility: { permissions.requestAccessibility() }
                ),
                AICommandsProvider { [weak self] destination in
                    self?.aiController?.show(destination)
                },
                ExtensionCommandsProvider(registry: extensionRegistry) { [weak self] installed, command in
                    self?.showExtension(installed: installed, command: command)
                }
            ])
            self.registry = registry

            let panel = LauncherPanel(keyEvents: keyEvents)
            panel.onPositionChanged = { [weak self] position in
                guard let store = self?.settingsStore else { return }
                do {
                    try store.update { $0.launcherPosition = position }
                } catch {
                    self?.toastCenter.show(error.localizedDescription)
                }
            }

            let launcherView = LauncherView(
                registry: registry,
                context: context,
                frecencyStore: frecencyStore,
                keyEvents: keyEvents,
                toasts: toastCenter,
                webSearchBangs: webSearchBangs,
                calculatorProvider: calculatorProvider,
                presentingCommands: makeLauncherPresentingCommands(
                    context: context,
                    clipboardStore: clipboardStore,
                    pasteService: pasteService,
                    fileSearchIndex: fileSearchIndex,
                    notesStore: notesStore,
                    calendarService: calendarService,
                    emojiStore: emojiStore,
                    emojiPasteService: emojiPasteService,
                    colorHistoryStore: colorHistoryStore,
                    menuItemIndex: menuItemIndex,
                    onHide: { [weak panel] returningFocus in
                        panel?.hide(returningFocus: returningFocus)
                    },
                    raycastImporter: raycastImporter
                ),
                navigationCoordinator: navigationCoordinator,
                onImportRayconfig: { [weak self] fileURL in
                    self?.navigationCoordinator.push(
                        RaycastImportPresentation.presentedView(
                            importer: raycastImporter,
                            fileURL: fileURL
                        )
                    )
                },
                onHide: { [weak panel] returnFocus in
                    panel?.hide(returningFocus: returnFocus)
                },
                onOpenSettings: { [weak self] in
                    self?.showSettings()
                }
            )
            let hostingView = NSHostingView(rootView: launcherView)
            hostingView.wantsLayer = true
            hostingView.layer?.cornerRadius = LauncherTheme.Metrics.panelCornerRadius
            hostingView.layer?.cornerCurve = .continuous
            hostingView.layer?.masksToBounds = true
            panel.contentView = hostingView
            self.panel = panel

            let hotkeyManager = HotkeyManager { [weak self] in
                self?.toggleLauncher()
            }
            try hotkeyManager.register(settingsStore.settings.hotkey)
            self.hotkeyManager = hotkeyManager
            appliedHotkeySettings = settingsStore.settings.hotkey

            if settingsStore.settings.hyperKey.enabled && permissions.inputMonitoring {
                try? hyperKeyManager.enable()
            }
            if settingsStore.settings.snippetsEnabled
                && permissions.accessibility
                && permissions.inputMonitoring {
                _ = snippetExpander.start()
            }
            if settingsStore.settings.dictationEnabled && dictationPermissions.isGranted {
                try? dictationController.startMonitoring()
            }
            clipboardMonitor.start()

            statusBarController = StatusBarController(
                onOpen: { [weak self] in self?.showLauncher() },
                onSettings: { [weak self] in self?.showSettings() }
            )

            applyTheme(settingsStore.settings.theme)
            appliedTheme = settingsStore.settings.theme
            observeSettingsAndStores()
            observeOpenNotification()

            if !settingsStore.settings.hasShownOnboarding {
                PermissionGuideOverlay.suppressed = true
                navigationCoordinator.push(LauncherPresentedView(
                    title: "Welcome to Omnicast",
                    content: AnyView(OnboardingPermissionsView(
                        permissions: permissions,
                        onContinue: { [weak self] in
                            self?.navigationCoordinator.pop()
                        }
                    )),
                    showsSearchField: false,
                    initialQuery: "",
                    onDismiss: { [weak self] in self?.finishOnboarding() }
                ))
                showLauncher()
            }
        } catch {
            presentStartupError(error)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        permissions?.refresh()
        if settingsStore?.settings.snippetsEnabled == true,
           snippetExpander?.isAvailable == true {
            _ = snippetExpander?.start()
        }
        if hyperKeyManager?.settings.enabled == true,
           hyperKeyManager?.isRunning == false {
            try? hyperKeyManager?.enable()
        }
        if settingsStore?.settings.dictationEnabled == true,
           dictationPermissions?.isGranted == true {
            try? dictationController?.startMonitoring()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        snippetExpander?.stop()
        try? hyperKeyManager?.disable()
        dictationController?.stopMonitoring()
        speechEngine?.stop()
        extensionHost?.stop()
        if let distributedObserver {
            DistributedNotificationCenter.default().removeObserver(distributedObserver)
        }
    }

    private func observeSettingsAndStores() {
        guard let settingsStore, let snippetStore, let quicklinkStore, let notesStore else { return }
        settingsStore.$settings
            .dropFirst()
            .sink { [weak self] settings in
                guard let self else { return }
                if self.appliedTheme != settings.theme {
                    self.applyTheme(settings.theme)
                    self.appliedTheme = settings.theme
                }
                do {
                    if self.hotkeyManager?.isShortcutCaptureActive != true,
                       self.appliedHotkeySettings != settings.hotkey {
                        try self.hotkeyManager?.register(settings.hotkey)
                        self.appliedHotkeySettings = settings.hotkey
                    }
                    if self.hyperKeyManager?.settings != settings.hyperKey {
                        try self.hyperKeyManager?.update(settings.hyperKey)
                    }
                } catch {
                    self.toastCenter.show(error.localizedDescription)
                }
                self.aiController?.update(settings: settings)
                let speechConfiguration = AppliedSpeechConfiguration(settings: settings)
                if self.appliedSpeechConfiguration != speechConfiguration,
                   let speechKeyStore = self.speechKeyStore {
                    self.speechEngine?.replace(with: makeSpeechEngine(
                        settings: settings,
                        keyStore: speechKeyStore
                    ))
                    self.appliedSpeechConfiguration = speechConfiguration
                }
                if settings.snippetsEnabled {
                    _ = self.snippetExpander?.start()
                } else {
                    self.snippetExpander?.stop()
                }
                if settings.dictationEnabled,
                   self.dictationPermissions?.isGranted == true {
                    do {
                        try self.dictationController?.startMonitoring()
                    } catch {
                        self.toastCenter.show(error.localizedDescription)
                    }
                } else {
                    self.dictationController?.stopMonitoring()
                }
            }
            .store(in: &subscriptions)

        snippetStore.$snippets
            .dropFirst()
            .sink { [weak self] _ in self?.refreshCommands() }
            .store(in: &subscriptions)

        quicklinkStore.$quicklinks
            .dropFirst()
            .sink { [weak self] _ in self?.refreshCommands() }
            .store(in: &subscriptions)

        notesStore.$notes
            .dropFirst()
            .sink { [weak self] _ in self?.refreshCommands() }
            .store(in: &subscriptions)
    }

    private func observeOpenNotification() {
        distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.omnicast.open"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.showLauncher() }
        }
    }

    private func refreshCommands() {
        guard let registry else { return }
        Task {
            await registry.invalidate()
            navigationCoordinator.reloadCommands()
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
        pasteService?.rememberFrontmostApplication()
        emojiPasteService?.rememberFrontmostApplication()
        menuItemIndex?.captureTargetApplication()
        panel?.showNearTop(position: settingsStore?.settings.launcherPosition)
    }

    private func finishOnboarding() {
        PermissionGuideOverlay.suppressed = false
        guard let settingsStore, !settingsStore.settings.hasShownOnboarding else { return }
        do {
            try settingsStore.update { $0.hasShownOnboarding = true }
        } catch {
            toastCenter.show(error.localizedDescription)
        }
    }

    private func showSettings() {
        panel?.hide(returningFocus: false)
        guard
            let settingsStore,
            let snippetStore,
            let quicklinkStore,
            let aiKeyStore,
            let permissions,
            let snippetEnableController,
            let hyperKeyEnableController,
            let dictationEnableController,
            let speechKeyStore,
            let extensionRegistry,
            let extensionStoreClient
        else { return }
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                store: settingsStore,
                snippetStore: snippetStore,
                quicklinkStore: quicklinkStore,
                aiKeyStore: aiKeyStore,
                permissions: permissions,
                snippetEnableController: snippetEnableController,
                hyperKeyEnableController: hyperKeyEnableController,
                dictationEnableController: dictationEnableController,
                speechKeyStore: speechKeyStore,
                extensionRegistry: extensionRegistry,
                extensionStoreClient: extensionStoreClient,
                onRegistryChanged: { [weak self] in self?.refreshCommands() },
                onHotkeyRecordingChanged: { [weak self] recording in
                    guard let self, let hotkey = self.settingsStore?.settings.hotkey else { return }
                    do {
                        try self.hotkeyManager?.setShortcutCaptureActive(recording, restoring: hotkey)
                        if !recording {
                            self.appliedHotkeySettings = hotkey
                        }
                    } catch {
                        self.toastCenter.show(error.localizedDescription)
                    }
                }
            )
        }
        settingsWindowController?.show()
    }

    private func showSnippetManager() {
        panel?.hide(returningFocus: false)
        guard let snippetStore else { return }
        if snippetWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Snippet Manager"
            window.contentView = NSHostingView(rootView: SnippetManagerView(store: snippetStore))
            window.isReleasedWhenClosed = false
            window.center()
            snippetWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        snippetWindow?.makeKeyAndOrderFront(nil)
    }

    private func showExtension(
        installed: InstalledExtension,
        command: ExtensionCommandManifest
    ) {
        guard let context = commandContext else { return }
        do {
            let host = try ExtensionHost(
                installedExtension: installed,
                commandName: command.name,
                directoryURL: OmnicastDataDirectory.defaultURL,
                clipboard: context.clipboard,
                opener: context.opener,
                callbacks: ExtensionHostCallbacks(
                    showToast: { [weak self] message in self?.toastCenter.show(message) },
                    showHUD: { [weak self] message in self?.toastCenter.show(message) },
                    closeMainWindow: { [weak self] in self?.navigationCoordinator.pop() }
                )
            )
            extensionHost?.stop()
            extensionHost = host
            navigationCoordinator.push(LauncherPresentedView(
                title: command.title,
                content: AnyView(ExtensionHostView(host: host)),
                showsSearchField: false,
                initialQuery: "",
                onDismiss: { [weak self, weak host] in
                    host?.stop()
                    if self?.extensionHost === host {
                        self?.extensionHost = nil
                    }
                }
            ))
        } catch {
            toastCenter.show(error.localizedDescription)
        }
    }

    private func resetWindowPosition() {
        do {
            try settingsStore?.update { $0.launcherPosition = nil }
            panel?.resetPosition()
            toastCenter.show("Window position reset")
        } catch {
            toastCenter.show(error.localizedDescription)
        }
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
