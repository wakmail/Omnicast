// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct AnthropicProvider: AIProvider, @unchecked Sendable {
    public let identifier = AIProviderIdentifier.anthropic
    public let defaultModel = "claude-sonnet-5"
    public let fallbackModels = [
        AIModel(id: "claude-sonnet-5", name: "Claude Sonnet 5"),
        AIModel(id: "claude-opus-5", name: "Claude Opus 5"),
        AIModel(id: "claude-haiku-4-5-20251001", name: "Claude Haiku")
    ]

    private let keyStore: any AIKeyStoring
    private let client: AIHTTPClient

    public init(keyStore: any AIKeyStoring, session: URLSession = .shared) {
        self.keyStore = keyStore
        client = AIHTTPClient(session: session)
    }

    public func stream(
        messages: [AIProviderMessage],
        model: String,
        options: AIStreamOptions
    ) -> AsyncThrowingStream<String, Error> {
        do {
            return client.streamSSE(
                request: try makeRequest(messages: messages, model: model, options: options),
                extract: { AIStreamParser.anthropicText(from: $0) }
            )
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
    }

    public func listModels() async throws -> [AIModel] {
        let key = try requiredKey()
        let request = AIRequestBuilder.get(
            url: URL(string: "https://api.anthropic.com/v1/models")!,
            headers: headers(key: key)
        )
        let data = try await client.data(for: request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let records = object?["data"] as? [[String: Any]] ?? []
        return records.compactMap { record in
            guard let id = record["id"] as? String else { return nil }
            return AIModel(id: id, name: record["display_name"] as? String)
        }
    }

    public func makeRequest(
        messages: [AIProviderMessage],
        model: String,
        options: AIStreamOptions
    ) throws -> URLRequest {
        let key = try requiredKey()
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": messages.map {
                ["role": $0.role.rawValue, "content": $0.content]
            },
            "stream": true
        ]
        if Self.supportsTemperature(model) {
            body["temperature"] = options.creativity
        }
        if let systemPrompt = options.systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }
        return try AIRequestBuilder.post(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            headers: headers(key: key),
            body: body
        )
    }

    public static func supportsTemperature(_ model: String) -> Bool {
        !model.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().hasPrefix("claude-opus-4-7")
    }

    private func requiredKey() throws -> String {
        guard let key = try keyStore.apiKey(for: identifier), !key.isEmpty else {
            throw AIProviderError.missingCredential(identifier)
        }
        return key
    }

    private func headers(key: String) -> [String: String] {
        [
            "x-api-key": key,
            "anthropic-version": "2023-06-01"
        ]
    }
}
