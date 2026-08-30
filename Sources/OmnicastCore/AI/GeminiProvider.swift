// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct GeminiProvider: AIProvider, @unchecked Sendable {
    public let identifier = AIProviderIdentifier.gemini
    public let defaultModel = "gemini-2.5-flash"
    public let fallbackModels = [
        AIModel(id: "gemini-2.5-pro", name: "Gemini 2.5 Pro"),
        AIModel(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash"),
        AIModel(id: "gemini-2.5-flash-lite", name: "Gemini 2.5 Flash Lite")
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
                extract: { AIStreamParser.geminiText(from: $0) }
            )
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
    }

    public func listModels() async throws -> [AIModel] {
        let key = try requiredKey()
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")!
        components.queryItems = [URLQueryItem(name: "key", value: key)]
        let data = try await client.data(for: AIRequestBuilder.get(url: components.url!, headers: [:]))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let records = object?["models"] as? [[String: Any]] ?? []
        return records.compactMap { record in
            let methods = record["supportedGenerationMethods"] as? [String] ?? []
            guard
                methods.isEmpty || methods.contains("generateContent"),
                var id = record["name"] as? String
            else { return nil }
            if id.hasPrefix("models/") { id.removeFirst(7) }
            return AIModel(id: id, name: record["displayName"] as? String)
        }
    }

    public func makeRequest(
        messages: [AIProviderMessage],
        model: String,
        options: AIStreamOptions
    ) throws -> URLRequest {
        let key = try requiredKey()
        let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):streamGenerateContent"
        )!
        components.queryItems = [
            URLQueryItem(name: "alt", value: "sse"),
            URLQueryItem(name: "key", value: key)
        ]
        let contents: [[String: Any]] = messages.map { message in
            [
                "role": message.role == .assistant ? "model" : "user",
                "parts": [["text": message.content]]
            ]
        }
        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": ["temperature": options.creativity]
        ]
        if let systemPrompt = options.systemPrompt, !systemPrompt.isEmpty {
            body["systemInstruction"] = ["parts": [["text": systemPrompt]]]
        }
        return try AIRequestBuilder.post(url: components.url!, headers: [:], body: body)
    }

    private func requiredKey() throws -> String {
        guard let key = try keyStore.apiKey(for: identifier), !key.isEmpty else {
            throw AIProviderError.missingCredential(identifier)
        }
        return key
    }
}
