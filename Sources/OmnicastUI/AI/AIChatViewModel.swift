// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore

@MainActor
public final class AIChatViewModel: ObservableObject {
    @Published public var input = ""
    @Published public var conversationSearch = ""
    @Published public private(set) var conversations: [AIChatConversation] = []
    @Published public private(set) var models: [AIModel] = []
    @Published public private(set) var streamingContent = ""
    @Published public private(set) var isStreaming = false
    @Published public private(set) var errorMessage: String?
    @Published public var activeConversationID: UUID?
    @Published public var selectedProvider: AIProviderIdentifier {
        didSet {
            guard oldValue != selectedProvider else { return }
            selectedModel = provider(for: selectedProvider)?.defaultModel ?? ""
            refreshModels()
        }
    }
    @Published public var selectedModel: String

    private let store: AIChatStore
    private let providers: [any AIProvider]
    private var subscriptions = Set<AnyCancellable>()
    private var streamTask: Task<Void, Never>?
    private var activeRequestID: UUID?

    public init(
        store: AIChatStore,
        providers: [any AIProvider],
        selectedProvider: AIProviderIdentifier? = nil
    ) {
        self.store = store
        self.providers = providers
        let initialProvider = selectedProvider ?? providers.first?.identifier ?? .openAI
        self.selectedProvider = initialProvider
        selectedModel = providers.first(where: { $0.identifier == initialProvider })?.defaultModel ?? ""
        conversations = store.conversations

        store.$conversations
            .sink { [weak self] values in self?.conversations = values }
            .store(in: &subscriptions)
        refreshModels()
    }

    public var availableProviders: [AIProviderIdentifier] {
        providers.map(\.identifier)
    }

    public var filteredConversations: [AIChatConversation] {
        store.search(conversationSearch)
    }

    public var activeConversation: AIChatConversation? {
        guard let activeConversationID else { return nil }
        return store.conversation(id: activeConversationID)
    }

    public var visibleMessages: [AIChatMessage] {
        activeConversation?.messages ?? []
    }

    public func refreshModels() {
        guard let provider = provider(for: selectedProvider) else {
            models = []
            return
        }
        models = provider.fallbackModels
        let expectedProvider = selectedProvider
        Task {
            do {
                let remoteModels = try await provider.listModels()
                guard expectedProvider == selectedProvider, !remoteModels.isEmpty else { return }
                models = remoteModels
                if !remoteModels.contains(where: { $0.id == selectedModel }) {
                    selectedModel = provider.defaultModel
                }
            } catch {
                guard expectedProvider == selectedProvider else { return }
            }
        }
    }

    public func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        guard let provider = provider(for: selectedProvider) else {
            errorMessage = "The selected AI provider is unavailable"
            return
        }

        do {
            let conversationID = try ensureConversation()
            let userMessage = AIChatMessage(role: .user, content: text)
            let conversation = try store.appendMessage(userMessage, to: conversationID)
            let requestMessages = conversation.messages.map {
                AIProviderMessage(role: $0.role, content: $0.content)
            }
            input = ""
            streamingContent = ""
            errorMessage = nil
            isStreaming = true

            let requestID = UUID()
            activeRequestID = requestID
            streamTask = Task { [weak self] in
                do {
                    for try await chunk in provider.stream(
                        messages: requestMessages,
                        model: self?.selectedModel ?? provider.defaultModel,
                        options: AIStreamOptions()
                    ) {
                        guard let self, self.activeRequestID == requestID else { return }
                        self.streamingContent += chunk
                    }
                    guard let self, self.activeRequestID == requestID else { return }
                    self.completeStream(cancelled: false)
                } catch {
                    guard let self, self.activeRequestID == requestID else { return }
                    if !Task.isCancelled {
                        self.errorMessage = error.localizedDescription
                    }
                    self.completeStream(cancelled: Task.isCancelled)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func stop() {
        guard isStreaming else { return }
        activeRequestID = nil
        streamTask?.cancel()
        streamTask = nil
        completeStream(cancelled: true)
    }

    public func newChat() {
        stop()
        activeConversationID = nil
        streamingContent = ""
        errorMessage = nil
        input = ""
    }

    public func selectConversation(_ id: UUID) {
        stop()
        guard let conversation = store.conversation(id: id) else { return }
        activeConversationID = id
        selectedProvider = conversation.provider
        selectedModel = conversation.model
        streamingContent = ""
        errorMessage = nil
    }

    public func deleteConversation(_ id: UUID) {
        do {
            if activeConversationID == id {
                newChat()
            }
            try store.deleteConversation(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureConversation() throws -> UUID {
        if let activeConversationID, store.conversation(id: activeConversationID) != nil {
            return activeConversationID
        }
        let conversation = try store.createConversation(
            provider: selectedProvider,
            model: selectedModel
        )
        activeConversationID = conversation.id
        return conversation.id
    }

    private func completeStream(cancelled: Bool) {
        let content = streamingContent
        if !content.isEmpty, let activeConversationID {
            do {
                try store.appendMessage(
                    AIChatMessage(role: .assistant, content: content, cancelled: cancelled),
                    to: activeConversationID
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        activeRequestID = nil
        streamTask = nil
        isStreaming = false
        streamingContent = ""
    }

    private func provider(for identifier: AIProviderIdentifier) -> (any AIProvider)? {
        providers.first { $0.identifier == identifier }
    }
}
