// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class AIProviderRequestTests: XCTestCase {
    func testOpenAIRequestMatchesChatShape() throws {
        let keys = InMemoryAIKeyStore(keys: [.openAI: "secret"])
        let provider = OpenAIProvider(keyStore: keys)
        let request = try provider.makeRequest(
            messages: [.init(role: .user, content: "Hello")],
            model: "gpt-4o-mini",
            options: AIStreamOptions(creativity: 0.4, systemPrompt: "Be concise")
        )
        let body = try jsonBody(request)
        let messages = body["messages"] as? [[String: Any]]

        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(body["model"] as? String, "gpt-4o-mini")
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(body["temperature"] as? Double, 0.4)
        XCTAssertEqual(messages?.first?["role"] as? String, "system")
        XCTAssertEqual(messages?.last?["content"] as? String, "Hello")
    }

    func testOpenAICompatibleURLAndReasoningShape() throws {
        let keys = InMemoryAIKeyStore(keys: [.openAICompatible: "secret"])
        let provider = OpenAIProvider(
            keyStore: keys,
            baseURL: URL(string: "http://127.0.0.1:9000")!,
            compatible: true
        )
        let request = try provider.makeRequest(
            messages: [.init(role: .user, content: "Reason")],
            model: "o3-mini",
            options: AIStreamOptions()
        )

        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:9000/v1/chat/completions")
        XCTAssertNil(try jsonBody(request)["temperature"])
        XCTAssertTrue(OpenAIProvider.isReasoningModel(" o1 "))
        XCTAssertFalse(OpenAIProvider.isReasoningModel("gpt-4o"))
    }

    func testAnthropicRequestMatchesMessagesShape() throws {
        let keys = InMemoryAIKeyStore(keys: [.anthropic: "secret"])
        let provider = AnthropicProvider(keyStore: keys)
        let request = try provider.makeRequest(
            messages: [.init(role: .assistant, content: "Previous")],
            model: "claude-sonnet-5",
            options: AIStreamOptions(creativity: 0.2, systemPrompt: "Helpful")
        )
        let body = try jsonBody(request)

        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(body["max_tokens"] as? Int, 4096)
        XCTAssertEqual(body["system"] as? String, "Helpful")
        XCTAssertEqual(body["temperature"] as? Double, 0.2)
        XCTAssertFalse(AnthropicProvider.supportsTemperature("claude-opus-4-7"))
    }

    func testGeminiRequestConvertsAssistantRole() throws {
        let keys = InMemoryAIKeyStore(keys: [.gemini: "secret key"])
        let provider = GeminiProvider(keyStore: keys)
        let request = try provider.makeRequest(
            messages: [.init(role: .assistant, content: "Previous")],
            model: "gemini-2.5-flash",
            options: AIStreamOptions(systemPrompt: "Helpful")
        )
        let body = try jsonBody(request)
        let contents = body["contents"] as? [[String: Any]]

        XCTAssertEqual(contents?.first?["role"] as? String, "model")
        XCTAssertNotNil(body["systemInstruction"])
        XCTAssertTrue(request.url?.absoluteString.contains("alt=sse") == true)
        XCTAssertTrue(request.url?.absoluteString.contains("key=secret%20key") == true)
    }

    func testOllamaRequestMatchesChatShape() throws {
        let provider = OllamaProvider(baseURL: URL(string: "http://localhost:11434/")!)
        let request = try provider.makeRequest(
            messages: [.init(role: .user, content: "Hello")],
            model: "llama3",
            options: AIStreamOptions(creativity: 0.9, systemPrompt: "Helpful")
        )
        let body = try jsonBody(request)
        let messages = body["messages"] as? [[String: Any]]

        XCTAssertEqual(request.url?.absoluteString, "http://localhost:11434/api/chat")
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(messages?.first?["role"] as? String, "system")
        XCTAssertEqual(messages?.last?["role"] as? String, "user")
    }

    private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
