// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public actor RaycastStoreCatalog {
    private let client: any RaycastStoreServing
    private let catalogLimit: Int
    private var cachedExtensions: [RaycastStoreExtension]?
    private var catalogTask: Task<[RaycastStoreExtension], Error>?
    private var screenshotCache: [String: [URL]] = [:]

    public init(
        client: any RaycastStoreServing,
        catalogLimit: Int = 1_000
    ) {
        self.client = client
        self.catalogLimit = catalogLimit
    }

    public func extensions() async throws -> [RaycastStoreExtension] {
        if let cachedExtensions {
            return cachedExtensions
        }
        if let catalogTask {
            return try await catalogTask.value
        }

        let client = self.client
        let limit = catalogLimit
        let task = Task {
            try await client.search(
                query: "",
                category: nil,
                limit: limit,
                offset: 0
            ).results
        }
        catalogTask = task
        do {
            let extensions = try await task.value
            cachedExtensions = extensions
            catalogTask = nil
            return extensions
        } catch {
            catalogTask = nil
            throw error
        }
    }

    public func search(query: String) async throws -> [RaycastStoreExtension] {
        let extensions = try await extensions()
        let terms = query
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: \Character.isWhitespace)
            .map(String.init)
        guard !terms.isEmpty else { return extensions }

        return extensions.filter { extensionValue in
            let commandText = extensionValue.commands
                .flatMap { [$0.name, $0.title, $0.description] }
                .joined(separator: " ")
            let searchable = [
                extensionValue.name,
                extensionValue.title,
                extensionValue.description,
                extensionValue.author,
                extensionValue.categories.joined(separator: " "),
                commandText
            ]
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return terms.allSatisfy(searchable.contains)
        }
    }

    public func screenshots(for extensionValue: RaycastStoreExtension) async throws -> [URL] {
        if !extensionValue.screenshotURLs.isEmpty {
            return extensionValue.screenshotURLs
        }
        if let cached = screenshotCache[extensionValue.name] {
            return cached
        }
        let values = try await client.screenshots(for: extensionValue.name)
        screenshotCache[extensionValue.name] = values
        return values
    }
}
