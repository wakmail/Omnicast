// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

@MainActor
final class AIChatStoreTests: XCTestCase {
    func testCRUDSearchAndPersistence() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
        let secondDate = firstDate.addingTimeInterval(10)

        let store = try AIChatStore(directoryURL: directory)
        let conversation = try store.createConversation(
            provider: .anthropic,
            model: "claude-sonnet-5",
            date: firstDate
        )
        let updated = try store.appendMessage(
            AIChatMessage(role: .user, content: "Explain Swift actors", date: secondDate),
            to: conversation.id,
            updatedAt: secondDate
        )

        XCTAssertEqual(updated.title, "Explain Swift actors")
        XCTAssertEqual(store.search("actors").map(\.id), [conversation.id])
        XCTAssertEqual(store.search("Anthropic").map(\.id), [conversation.id])
        XCTAssertEqual(store.search("sonnet").map(\.id), [conversation.id])

        let loaded = try AIChatStore(directoryURL: directory)
        XCTAssertEqual(loaded.conversations, store.conversations)
        XCTAssertEqual(loaded.conversation(id: conversation.id)?.messages.count, 1)

        XCTAssertTrue(try loaded.deleteConversation(id: conversation.id))
        XCTAssertFalse(try loaded.deleteConversation(id: conversation.id))
        XCTAssertTrue(loaded.conversations.isEmpty)
    }

    func testReplaceRenameAndDeleteAll() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AIChatStore(directoryURL: directory)
        let conversation = try store.createConversation(
            title: "Original",
            provider: .ollama,
            model: "llama3"
        )
        let messages = [AIChatMessage(role: .assistant, content: "Local answer")]

        try store.replaceMessages(messages, in: conversation.id)
        try store.renameConversation(id: conversation.id, title: "Renamed")
        XCTAssertEqual(store.conversation(id: conversation.id)?.title, "Renamed")
        XCTAssertEqual(store.conversation(id: conversation.id)?.messages, messages)

        try store.deleteAll()
        XCTAssertTrue(store.conversations.isEmpty)
    }

    func testConversationLimitUsesMostRecentlyUpdated() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AIChatStore(directoryURL: directory, maximumConversationCount: 2)

        for index in 0..<3 {
            try store.createConversation(
                title: "Chat \(index)",
                provider: .openAI,
                model: "gpt-4o-mini",
                date: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        XCTAssertEqual(store.conversations.map(\.title), ["Chat 2", "Chat 1"])
    }

    func testTitleNormalizationAndTruncation() {
        XCTAssertEqual(AIChatStore.makeTitle("  hello   world  "), "hello world")
        let longTitle = AIChatStore.makeTitle(String(repeating: "a", count: 60))
        XCTAssertEqual(longTitle.count, 49)
        XCTAssertTrue(longTitle.hasSuffix("…"))
        XCTAssertEqual(AIChatStore.makeTitle("   "), "New Chat")
    }
}
