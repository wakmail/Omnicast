// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

public struct AIChatMessage: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var role: AIMessageRole
    public var content: String
    public var date: Date
    public var cancelled: Bool

    public init(
        id: UUID = UUID(),
        role: AIMessageRole,
        content: String,
        date: Date = Date(),
        cancelled: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.date = date
        self.cancelled = cancelled
    }
}

public struct AIChatConversation: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var provider: AIProviderIdentifier
    public var model: String
    public var messages: [AIChatMessage]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        provider: AIProviderIdentifier,
        model: String,
        messages: [AIChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.provider = provider
        self.model = model
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@MainActor
public final class AIChatStore: ObservableObject {
    @Published public private(set) var conversations: [AIChatConversation]
    public let fileURL: URL

    private let maximumConversationCount: Int

    public init(
        directoryURL: URL = OmnicastDataDirectory.defaultURL,
        maximumConversationCount: Int = 50
    ) throws {
        fileURL = directoryURL.appendingPathComponent("ai-chat-conversations.json")
        self.maximumConversationCount = maximumConversationCount
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            conversations = try decoder.decode(StoreData.self, from: data).conversations
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(maximumConversationCount)
                .map { $0 }
        } else {
            conversations = []
        }
    }

    @discardableResult
    public func createConversation(
        title: String = "New Chat",
        provider: AIProviderIdentifier,
        model: String,
        messages: [AIChatMessage] = [],
        date: Date = Date()
    ) throws -> AIChatConversation {
        let conversation = AIChatConversation(
            title: title,
            provider: provider,
            model: model,
            messages: messages,
            createdAt: date,
            updatedAt: date
        )
        try upsert(conversation)
        return conversation
    }

    public func conversation(id: UUID) -> AIChatConversation? {
        conversations.first { $0.id == id }
    }

    public func upsert(_ conversation: AIChatConversation) throws {
        var next = conversations.filter { $0.id != conversation.id }
        next.append(conversation)
        conversations = sortedAndLimited(next)
        try save()
    }

    @discardableResult
    public func appendMessage(
        _ message: AIChatMessage,
        to conversationID: UUID,
        updatedAt: Date = Date()
    ) throws -> AIChatConversation {
        guard var conversation = conversation(id: conversationID) else {
            throw AIChatStoreError.notFound
        }
        conversation.messages.append(message)
        conversation.updatedAt = updatedAt
        if conversation.title == "New Chat", message.role == .user {
            conversation.title = Self.makeTitle(message.content)
        }
        try upsert(conversation)
        return conversation
    }

    @discardableResult
    public func replaceMessages(
        _ messages: [AIChatMessage],
        in conversationID: UUID,
        updatedAt: Date = Date()
    ) throws -> AIChatConversation {
        guard var conversation = conversation(id: conversationID) else {
            throw AIChatStoreError.notFound
        }
        conversation.messages = messages
        conversation.updatedAt = updatedAt
        if conversation.title == "New Chat",
           let firstUserMessage = messages.first(where: { $0.role == .user }) {
            conversation.title = Self.makeTitle(firstUserMessage.content)
        }
        try upsert(conversation)
        return conversation
    }

    @discardableResult
    public func renameConversation(id: UUID, title: String, updatedAt: Date = Date()) throws -> AIChatConversation {
        guard var conversation = conversation(id: id) else {
            throw AIChatStoreError.notFound
        }
        conversation.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        conversation.updatedAt = updatedAt
        try upsert(conversation)
        return conversation
    }

    @discardableResult
    public func deleteConversation(id: UUID) throws -> Bool {
        let previousCount = conversations.count
        conversations.removeAll { $0.id == id }
        guard conversations.count != previousCount else { return false }
        try save()
        return true
    }

    public func deleteAll() throws {
        conversations = []
        try save()
    }

    public func search(_ query: String) -> [AIChatConversation] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return conversations }
        return conversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(term)
                || conversation.provider.displayName.localizedCaseInsensitiveContains(term)
                || conversation.model.localizedCaseInsensitiveContains(term)
                || conversation.messages.contains {
                    $0.content.localizedCaseInsensitiveContains(term)
                }
        }
    }

    public static func makeTitle(_ text: String) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !words.isEmpty else { return "New Chat" }
        guard words.count > 48 else { return words }
        return String(words.prefix(48)) + "…"
    }

    private func sortedAndLimited(_ values: [AIChatConversation]) -> [AIChatConversation] {
        Array(values.sorted { $0.updatedAt > $1.updatedAt }.prefix(maximumConversationCount))
    }

    private func save() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(StoreData(version: 1, conversations: conversations))
            .write(to: fileURL, options: .atomic)
    }
}

private struct StoreData: Codable {
    let version: Int
    let conversations: [AIChatConversation]
}

public enum AIChatStoreError: LocalizedError {
    case notFound

    public var errorDescription: String? {
        "The AI conversation was not found"
    }
}
