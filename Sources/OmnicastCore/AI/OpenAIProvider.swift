// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct OpenAIProvider: AIProvider, @unchecked Sendable {
    public let identifier: AIProviderIdentifier
    public let defaultModel: String
    public let fallbackModels: [AIModel]

    private let keyStore: any AIKeyStoring
    private let baseURL: URL
    private let appendV1: Bool
    private let client: AIHTTPClient

    public init(
        keyStore: any AIKeyStoring,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        appendV1: Bool = true,
        compatible: Bool = false,
        defaultModel: String? = nil,
        session: URLSession = .shared
    ) {
        identifier = compatible ? .openAICompatible : .openAI
        self.keyStore = keyStore
        self.baseURL = baseURL
        self.appendV1 = appendV1
        self.defaultModel = defaultModel ?? (compatible ? "gpt-4o" : "gpt-4o-mini")
        fallbackModels = compatible
            ? [AIModel(id: defaultModel ?? "gpt-4o")]
            : [
                AIModel(id: "gpt-4o"),
                AIModel(id: "gpt-4o-mini"),
                AIModel(id: "gpt-4-turbo"),
                AIModel(id: "gpt-3.5-turbo"),
                AIModel(id: "o1"),
                AIModel(id: "o1-mini"),
                AIModel(id: "o3-mini")
            ]
        client = AIHTTPClient(session: session)
    }

    public func stream(
        messages: [AIProviderMessage],
        model: String,
        options: AIStreamOptions
    ) -> AsyncThrowingStream<String, Error> {
        do {
            let request = try makeRequest(messages: messages, model: model, options: options)
            return client.streamSSE(request: request) { AIStreamParser.openAIText(from: $0) }
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
    }

    public func listModels() async throws -> [AIModel] {
        let key = try requiredKey()
        let url = try endpointURL(path: "models")
        let request = AIRequestBuilder.get(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )
        let data = try await client.data(for: request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let records = object?["data"] as? [[String: Any]] ?? []
        return records.compactMap { record in
            guard let id = record["id"] as? String else { return nil }
            return AIModel(id: id)
        }.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    public func makeRequest(
        messages: [AIProviderMessage],
        model: String,
        options: AIStreamOptions
    ) throws -> URLRequest {
        let key = try requiredKey()
        var fullMessages: [[String: Any]] = []
        if let systemPrompt = options.systemPrompt, !systemPrompt.isEmpty {
            fullMessages.append(["role": "system", "content": systemPrompt])
        }
        fullMessages.append(contentsOf: messages.map {
            ["role": $0.role.rawValue, "content": $0.content]
        })

        var body: [String: Any] = [
            "model": model,
            "messages": fullMessages,
            "stream": true
        ]
        if !Self.isReasoningModel(model) {
            body["temperature"] = options.creativity
        }
        return try AIRequestBuilder.post(
            url: endpointURL(path: "chat/completions"),
            headers: ["Authorization": "Bearer \(key)"],
            body: body
        )
    }

    public static func isReasoningModel(_ model: String) -> Bool {
        let value = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.first == "o", value.count > 1 else { return false }
        return value.dropFirst().first?.isNumber == true
    }

    private func requiredKey() throws -> String {
        guard let key = try keyStore.apiKey(for: identifier), !key.isEmpty else {
            throw AIProviderError.missingCredential(identifier)
        }
        return key
    }

    private func endpointURL(path: String) throws -> URL {
        var value = baseURL.absoluteString
        while value.hasSuffix("/") { value.removeLast() }
        if appendV1 && !value.hasSuffix("/v1") {
            value += "/v1"
        }
        guard let url = URL(string: "\(value)/\(path)") else {
            throw AIProviderError.invalidBaseURL(baseURL.absoluteString)
        }
        return url
    }
}
