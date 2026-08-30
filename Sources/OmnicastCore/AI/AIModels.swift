// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum AIProviderIdentifier: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI = "openai"
    case anthropic
    case gemini
    case ollama
    case openAICompatible = "openai-compatible"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Gemini"
        case .ollama: "Ollama"
        case .openAICompatible: "OpenAI Compatible"
        }
    }
}

public enum AIMessageRole: String, Codable, Sendable {
    case user
    case assistant
}

public struct AIProviderMessage: Codable, Equatable, Sendable {
    public var role: AIMessageRole
    public var content: String

    public init(role: AIMessageRole, content: String) {
        self.role = role
        self.content = content
    }
}

public struct AIStreamOptions: Equatable, Sendable {
    public var creativity: Double
    public var systemPrompt: String?

    public init(creativity: Double = 0.7, systemPrompt: String? = nil) {
        self.creativity = creativity
        self.systemPrompt = systemPrompt
    }
}

public struct AIModel: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String? = nil) {
        self.id = id
        self.name = name ?? id
    }
}

public enum AIProviderError: LocalizedError, Equatable {
    case missingCredential(AIProviderIdentifier)
    case invalidBaseURL(String)
    case invalidResponse
    case requestAborted
    case httpStatus(Int, String)
    case emptyResponse(String)

    public var errorDescription: String? {
        switch self {
        case .missingCredential(let provider):
            "No API key is configured for \(provider.displayName)"
        case .invalidBaseURL(let value):
            "The AI provider URL is invalid: \(value)"
        case .invalidResponse:
            "The AI provider returned an invalid response"
        case .requestAborted:
            "Request aborted"
        case .httpStatus(let status, let body):
            "HTTP \(status): \(body)"
        case .emptyResponse(let provider):
            "\(provider) returned no text"
        }
    }
}
