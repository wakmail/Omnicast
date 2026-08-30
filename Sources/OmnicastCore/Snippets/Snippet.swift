// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct Snippet: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var keyword: String?
    public var content: String
    public let created: Date
    public var lastUsed: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        keyword: String? = nil,
        content: String,
        created: Date = Date(),
        lastUsed: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.content = content
        self.created = created
        self.lastUsed = lastUsed
    }
}

public struct SnippetImportResult: Equatable, Sendable {
    public let imported: Int
    public let skipped: Int
    public let failed: Int

    public init(imported: Int, skipped: Int, failed: Int) {
        self.imported = imported
        self.skipped = skipped
        self.failed = failed
    }
}

public enum SnippetStoreError: LocalizedError, Equatable {
    case emptyName
    case emptyContent
    case invalidKeyword
    case invalidImport

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "A snippet name is required"
        case .emptyContent:
            return "Snippet content is required"
        case .invalidKeyword:
            return "A keyword cannot contain quote characters"
        case .invalidImport:
            return "The selected file is not a supported snippet export"
        }
    }
}
