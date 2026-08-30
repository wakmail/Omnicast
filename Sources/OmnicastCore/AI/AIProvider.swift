// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public protocol AIProvider: Sendable {
    var identifier: AIProviderIdentifier { get }
    var displayName: String { get }
    var defaultModel: String { get }
    var fallbackModels: [AIModel] { get }

    func stream(
        messages: [AIProviderMessage],
        model: String,
        options: AIStreamOptions
    ) -> AsyncThrowingStream<String, Error>

    func listModels() async throws -> [AIModel]
}

public extension AIProvider {
    var displayName: String { identifier.displayName }
    var fallbackModels: [AIModel] { [AIModel(id: defaultModel)] }
}
