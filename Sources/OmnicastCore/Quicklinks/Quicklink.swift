// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct Quicklink: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var urlTemplate: String
    public var openWithAppBundleIdentifier: String?
    public var icon: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        urlTemplate: String,
        openWithAppBundleIdentifier: String? = nil,
        icon: String = "Globe",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.urlTemplate = urlTemplate
        self.openWithAppBundleIdentifier = openWithAppBundleIdentifier
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var requiresArgument: Bool {
        urlTemplate.range(of: "{query}", options: .caseInsensitive) != nil
    }

    public func resolvedURL(query: String? = nil) throws -> URL {
        var resolved = urlTemplate
        if requiresArgument {
            guard let query,
                  !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw QuicklinkError.missingQuery
            }
            resolved = resolved.replacingOccurrences(
                of: "{query}",
                with: Self.percentEncode(query),
                options: .caseInsensitive
            )
        }
        guard let url = URL(string: resolved) else {
            throw QuicklinkError.invalidURLTemplate
        }
        return url
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

public enum QuicklinkError: Error, Equatable, LocalizedError {
    case missingName
    case missingURLTemplate
    case invalidURLTemplate
    case missingQuery
    case notFound

    public var errorDescription: String? {
        switch self {
        case .missingName: return "Quick link name is required."
        case .missingURLTemplate: return "Quick link URL is required."
        case .invalidURLTemplate: return "Quick link URL is invalid."
        case .missingQuery: return "A search query is required."
        case .notFound: return "Quick link was not found."
        }
    }
}

public struct QuicklinkImportResult: Equatable, Sendable {
    public let found: Int
    public let imported: Int
    public let skipped: Int
    public let failed: Int

    public init(found: Int, imported: Int, skipped: Int, failed: Int) {
        self.found = found
        self.imported = imported
        self.skipped = skipped
        self.failed = failed
    }
}
