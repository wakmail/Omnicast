// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import OmnicastCore
import OmnicastUI
import SwiftUI

@MainActor
final class AIWindowController {
    private let keyStore: AIKeyStore
    private let chatStore: AIChatStore
    private let onShow: () -> Void
    private var window: NSWindow?
    private var viewModel: AIChatViewModel?
    private var configuration: AIConfiguration?

    init(
        keyStore: AIKeyStore,
        chatStore: AIChatStore,
        settings: AppSettings,
        onShow: @escaping () -> Void
    ) {
        self.keyStore = keyStore
        self.chatStore = chatStore
        self.onShow = onShow
        update(settings: settings)
    }

    func update(settings: AppSettings) {
        let configuration = AIConfiguration(settings: settings)
        guard self.configuration != configuration else { return }
        var providers: [any AIProvider] = [
            OpenAIProvider(keyStore: keyStore),
            AnthropicProvider(keyStore: keyStore),
            GeminiProvider(keyStore: keyStore),
            OllamaProvider()
        ]
        if settings.openAICompatibleEnabled,
           let url = URL(string: settings.openAICompatibleBaseURL),
           !settings.openAICompatibleBaseURL.isEmpty {
            providers.append(OpenAIProvider(
                keyStore: keyStore,
                baseURL: url,
                compatible: true,
                defaultModel: settings.defaultAIModel
            ))
        }
        let selectedProvider = providers.contains { $0.identifier == settings.defaultAIProvider }
            ? settings.defaultAIProvider
            : providers[0].identifier
        let viewModel = AIChatViewModel(
            store: chatStore,
            providers: providers,
            selectedProvider: selectedProvider
        )
        if !settings.defaultAIModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.selectedModel = settings.defaultAIModel
        }
        self.viewModel = viewModel
        self.configuration = configuration

        let window = window ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 580),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AI Chat"
        window.contentView = NSHostingView(rootView: AIChatView(viewModel: viewModel))
        window.isReleasedWhenClosed = false
        if self.window == nil { window.center() }
        self.window = window
    }

    func show(_ destination: AICommandDestination) {
        onShow()
        if case .ask = destination {
            viewModel?.newChat()
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
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
