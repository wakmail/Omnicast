// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct OllamaProvider: AIProvider, @unchecked Sendable {
    public let identifier = AIProviderIdentifier.ollama
    public let defaultModel = "llama3"
    public let fallbackModels = [
        AIModel(id: "llama3", name: "Llama 3"),
        AIModel(id: "mistral", name: "Mistral"),
        AIModel(id: "codellama", name: "Code Llama")
    ]

    private let baseURL: URL
    private let client: AIHTTPClient

    public init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        client = AIHTTPClient(session: session)
    }

    public func stream(
        messages: [AIProviderMessage],
        model: String,
        options: AIStreamOptions
    ) -> AsyncThrowingStream<String, Error> {
        do {
            return client.streamLines(
                request: try makeRequest(messages: messages, model: model, options: options),
                extract: { AIStreamParser.ollamaText(from: $0) }
            )
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
    }

    public func listModels() async throws -> [AIModel] {
        let request = AIRequestBuilder.get(url: try endpointURL(path: "api/tags"), headers: [:])
        let data = try await client.data(for: request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let records = object?["models"] as? [[String: Any]] ?? []
        return records.compactMap { record in
            guard let id = (record["name"] ?? record["model"]) as? String else { return nil }
            return AIModel(id: id)
        }
    }

    public func makeRequest(
        messages: [AIProviderMessage],
        model: String,
        options: AIStreamOptions
    ) throws -> URLRequest {
        var fullMessages: [[String: Any]] = []
        if let systemPrompt = options.systemPrompt, !systemPrompt.isEmpty {
            fullMessages.append(["role": "system", "content": systemPrompt])
        }
        fullMessages.append(contentsOf: messages.map {
            ["role": $0.role.rawValue, "content": $0.content]
        })
        let body: [String: Any] = [
            "model": model,
            "messages": fullMessages,
            "stream": true,
            "options": ["temperature": options.creativity]
        ]
        return try AIRequestBuilder.post(
            url: endpointURL(path: "api/chat"),
            headers: [:],
            body: body
        )
    }

    private func endpointURL(path: String) throws -> URL {
        var value = baseURL.absoluteString
        while value.hasSuffix("/") { value.removeLast() }
        guard let url = URL(string: "\(value)/\(path)") else {
            throw AIProviderError.invalidBaseURL(baseURL.absoluteString)
        }
        return url
    }
}
