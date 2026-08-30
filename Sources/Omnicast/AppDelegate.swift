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
    private var aiWindow: NSWindow?
    private var settingsStore: SettingsStore?
    private var registry: CommandRegistry?
    private var commandContext: CommandContext?

    private var clipboardStore: ClipboardHistoryStore?
    private var clipboardMonitor: ClipboardMonitor?
    private var pasteService: PasteService?
    private var snippetStore: SnippetStore?
    private var snippetExpander: SnippetExpander?
    private var quicklinkStore: QuicklinkStore?
    private var fileSearchIndex: FileSearchIndex?

    private var aiKeyStore: AIKeyStore?
    private var aiChatStore: AIChatStore?
    private var aiViewModel: AIChatViewModel?
    private var aiConfiguration: AIConfiguration?
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
            let aiKeyStore = AIKeyStore()
            let aiChatStore = try AIChatStore()
            let extensionStoreClient = RaycastStoreClient()
            let extensionRegistry = ExtensionRegistry(store: extensionStoreClient)
            let hyperKeyManager = HyperKeyManager(settings: settingsStore.settings.hyperKey)

            self.settingsStore = settingsStore
            self.clipboardStore = clipboardStore
            self.clipboardMonitor = clipboardMonitor
            self.pasteService = pasteService
            self.snippetStore = snippetStore
            self.snippetExpander = snippetExpander
            self.quicklinkStore = quicklinkStore
            self.fileSearchIndex = fileSearchIndex
            self.aiKeyStore = aiKeyStore
            self.aiChatStore = aiChatStore
            self.extensionStoreClient = extensionStoreClient
            self.extensionRegistry = extensionRegistry
            self.hyperKeyManager = hyperKeyManager

            pasteService.didWritePasteboard = { [weak clipboardMonitor] in
                clipboardMonitor?.ignoreCurrentPasteboardContents()
            }

            let clipboardService = SystemClipboardService()
            let opener = WorkspaceOpenerService()
            let context = CommandContext(
                clipboard: clipboardService,
                opener: opener,
                toasts: toastCenter
            )
            commandContext = context

            let registry = CommandRegistry(providers: [
                ApplicationsProvider(),
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
                WindowCommandsProvider(adjuster: windowAdjuster),
                AICommandsProvider { [weak self] destination in
                    self?.showAIChat(destination)
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
                presentingCommands: makePresentingCommands(context: context),
                navigationCoordinator: navigationCoordinator,
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

            if settingsStore.settings.hyperKey.enabled {
                try? hyperKeyManager.enable()
            }
            if snippetExpander.isAvailable {
                _ = snippetExpander.start()
            }
            clipboardMonitor.start()

            statusBarController = StatusBarController(
                onOpen: { [weak self] in self?.showLauncher() },
                onSettings: { [weak self] in self?.showSettings() }
            )

            configureAI(settings: settingsStore.settings)
            applyTheme(settingsStore.settings.theme)
            appliedTheme = settingsStore.settings.theme
            observeSettingsAndStores()
            observeOpenNotification()

            if !settingsStore.settings.hasShownOnboarding {
                navigationCoordinator.push(LauncherPresentedView(
                    title: "Welcome to Omnicast",
                    content: AnyView(OnboardingPermissionsView(
                        windowAdjuster: windowAdjuster,
                        hyperKeyManager: hyperKeyManager,
                        snippetExpander: snippetExpander
                    )),
                    showsSearchField: false,
                    initialQuery: ""
                ))
                try settingsStore.update { $0.hasShownOnboarding = true }
                showLauncher()
            }
        } catch {
            presentStartupError(error)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if snippetExpander?.isAvailable == true {
            _ = snippetExpander?.start()
        }
        if hyperKeyManager?.settings.enabled == true,
           hyperKeyManager?.isRunning == false {
            try? hyperKeyManager?.enable()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        snippetExpander?.stop()
        try? hyperKeyManager?.disable()
        extensionHost?.stop()
        if let distributedObserver {
            DistributedNotificationCenter.default().removeObserver(distributedObserver)
        }
    }

    private func makePresentingCommands(
        context: CommandContext
    ) -> [String: LauncherCommandPresenter] {
        [
            "clipboard:history": { [unowned self] query in
                guard let store = clipboardStore, let pasteService else {
                    return LauncherPresentedView(
                        title: "Clipboard History",
                        content: AnyView(EmptyView())
                    )
                }
                let model = ClipboardHistoryViewModel(
                    store: store,
                    pasteService: pasteService,
                    onDismiss: { [weak self] in
                        self?.panel?.hide(returningFocus: false)
                    }
                )
                model.query = query
                return LauncherPresentedView(
                    title: "Clipboard History",
                    content: AnyView(ClipboardHistoryView(
                        viewModel: model,
                        showsChrome: false
                    )),
                    initialQuery: query,
                    onQueryChange: { [weak model] in model?.query = $0 },
                    onKey: { [weak model] key in
                        guard let model else { return false }
                        switch key {
                        case .moveUp: model.handle(.moveSelectionUp)
                        case .moveDown: model.handle(.moveSelectionDown)
                        case .enter: model.handle(.pasteSelected)
                        case .commandEnter: model.handle(.copySelected)
                        default: return false
                        }
                        return true
                    }
                )
            },
            "file-search": { [unowned self] query in
                guard let fileSearchIndex else {
                    return LauncherPresentedView(
                        title: "File Search",
                        content: AnyView(EmptyView())
                    )
                }
                let model = FileSearchViewModel(
                    index: fileSearchIndex,
                    context: context,
                    onOpen: { [weak self] in self?.panel?.hide(returningFocus: true) }
                )
                model.updateQuery(query)
                return LauncherPresentedView(
                    title: "Files",
                    content: AnyView(FileSearchView(model: model)),
                    initialQuery: query,
                    onQueryChange: { [weak model] in model?.updateQuery($0) },
                    onKey: { [weak model] key in model?.handle(key) ?? false }
                )
            }
        ]
    }

    private func observeSettingsAndStores() {
        guard let settingsStore, let snippetStore, let quicklinkStore else { return }
        settingsStore.$settings
            .dropFirst()
            .sink { [weak self] settings in
                guard let self else { return }
                if self.appliedTheme != settings.theme {
                    self.applyTheme(settings.theme)
                    self.appliedTheme = settings.theme
                }
                do {
                    if self.appliedHotkeySettings != settings.hotkey {
                        try self.hotkeyManager?.register(settings.hotkey)
                        self.appliedHotkeySettings = settings.hotkey
                    }
                    if self.hyperKeyManager?.settings != settings.hyperKey {
                        try self.hyperKeyManager?.update(settings.hyperKey)
                    }
                } catch {
                    self.toastCenter.show(error.localizedDescription)
                }
                if self.aiConfiguration != AIConfiguration(settings: settings) {
                    self.configureAI(settings: settings)
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
        settingsWindowController?.close()
        pasteService?.rememberFrontmostApplication()
        panel?.showNearTop(position: settingsStore?.settings.launcherPosition)
    }

    private func showSettings() {
        panel?.hide(returningFocus: false)
        guard
            let settingsStore,
            let snippetStore,
            let snippetExpander,
            let quicklinkStore,
            let aiKeyStore,
            let hyperKeyManager,
            let extensionRegistry,
            let extensionStoreClient
        else { return }
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                store: settingsStore,
                snippetStore: snippetStore,
                snippetExpander: snippetExpander,
                quicklinkStore: quicklinkStore,
                aiKeyStore: aiKeyStore,
                windowAdjuster: windowAdjuster,
                hyperKeyManager: hyperKeyManager,
                extensionRegistry: extensionRegistry,
                extensionStoreClient: extensionStoreClient,
                onRegistryChanged: { [weak self] in self?.refreshCommands() }
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

    private func configureAI(settings: AppSettings) {
        guard let aiKeyStore, let aiChatStore else { return }
        var providers: [any AIProvider] = [
            OpenAIProvider(keyStore: aiKeyStore),
            AnthropicProvider(keyStore: aiKeyStore),
            GeminiProvider(keyStore: aiKeyStore),
            OllamaProvider()
        ]
        if settings.openAICompatibleEnabled,
           let url = URL(string: settings.openAICompatibleBaseURL),
           !settings.openAICompatibleBaseURL.isEmpty {
            providers.append(OpenAIProvider(
                keyStore: aiKeyStore,
                baseURL: url,
                compatible: true,
                defaultModel: settings.defaultAIModel
            ))
        }
        let selectedProvider = providers.contains { $0.identifier == settings.defaultAIProvider }
            ? settings.defaultAIProvider
            : providers[0].identifier
        let viewModel = AIChatViewModel(
            store: aiChatStore,
            providers: providers,
            selectedProvider: selectedProvider
        )
        if !settings.defaultAIModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.selectedModel = settings.defaultAIModel
        }
        aiViewModel = viewModel
        aiConfiguration = AIConfiguration(settings: settings)

        let window = aiWindow ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 580),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AI Chat"
        window.contentView = NSHostingView(rootView: AIChatView(viewModel: viewModel))
        window.isReleasedWhenClosed = false
        if aiWindow == nil { window.center() }
        aiWindow = window
    }

    private func showAIChat(_ destination: AICommandDestination) {
        panel?.hide(returningFocus: false)
        if case .ask = destination {
            aiViewModel?.newChat()
        }
        NSApp.activate(ignoringOtherApps: true)
        aiWindow?.makeKeyAndOrderFront(nil)
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

private struct AIConfiguration: Equatable {
    let provider: AIProviderIdentifier
    let model: String
    let compatibleEnabled: Bool
    let compatibleBaseURL: String

    init(settings: AppSettings) {
        provider = settings.defaultAIProvider
        model = settings.defaultAIModel
        compatibleEnabled = settings.openAICompatibleEnabled
        compatibleBaseURL = settings.openAICompatibleBaseURL
    }
}

private struct ResetWindowPositionProvider: CommandProvider {
    let reset: @MainActor @Sendable () -> Void

    func commands() async -> [any Command] {
        [ResetWindowPositionCommand(reset: reset)]
    }
}

private struct ResetWindowPositionCommand: Command {
    let reset: @MainActor @Sendable () -> Void
    let id = "system:reset-window-position"
    let title = "Reset Window Position"
    let subtitle = "Move the launcher to its default position"
    let icon: CommandIcon = .sfSymbol("rectangle.center.inset.filled")
    let keywords = ["launcher", "panel", "center", "position"]
    let kind: CommandKind = .system

    @MainActor
    func execute(context: CommandContext) async throws {
        reset()
    }
}
