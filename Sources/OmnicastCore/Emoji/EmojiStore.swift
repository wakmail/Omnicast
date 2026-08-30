// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct EmojiEntry: Codable, Equatable, Sendable {
    public let name: String
    public let emoji: String
    public let keywords: [String]

    public init(name: String, emoji: String, keywords: [String] = []) {
        self.name = name
        self.emoji = emoji
        self.keywords = keywords
    }

    private enum CodingKeys: String, CodingKey {
        case name = "n"
        case emoji = "e"
        case keywords = "k"
    }
}

public enum EmojiStoreError: LocalizedError {
    case resourceMissing

    public var errorDescription: String? {
        switch self {
        case .resourceMissing:
            return "Emoji data is unavailable"
        }
    }
}

public struct EmojiStore: Sendable {
    public let entries: [EmojiEntry]

    public init(entries: [EmojiEntry]) {
        self.entries = entries
    }

    public init(data: Data) throws {
        entries = try JSONDecoder().decode([EmojiEntry].self, from: data)
    }

    public init() throws {
        guard let url = Bundle.module.url(
            forResource: "emoji-data",
            withExtension: "json"
        ) else {
            throw EmojiStoreError.resourceMissing
        }
        try self.init(data: Data(contentsOf: url))
    }

    public func search(_ query: String, limit: Int = 200) -> [EmojiEntry] {
        let availableLimit = max(0, limit)
        guard availableLimit > 0 else { return [] }
        let normalizedQuery = Self.normalized(query)
        guard !normalizedQuery.isEmpty else {
            return Array(entries.prefix(availableLimit))
        }

        return entries.enumerated()
            .compactMap { index, entry -> RankedEmoji? in
                guard let score = Self.score(entry, query: normalizedQuery) else {
                    return nil
                }
                return RankedEmoji(entry: entry, score: score, originalIndex: index)
            }
            .sorted { left, right in
                if left.score != right.score {
                    return left.score < right.score
                }
                return left.originalIndex < right.originalIndex
            }
            .prefix(availableLimit)
            .map(\.entry)
    }

    public static func normalized(_ value: String) -> String {
        let spaced = value.replacingOccurrences(of: "_", with: " ")
        let transliterated = spaced.applyingTransform(.toLatin, reverse: false) ?? spaced
        return transliterated
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func score(_ entry: EmojiEntry, query: String) -> Int? {
        let name = normalized(entry.name)
        let keywords = entry.keywords.map(normalized)
        if name == query { return 0 }
        if name.hasPrefix(query) { return 1 }
        if keywords.contains(where: { $0.hasPrefix(query) }) { return 2 }
        if name.contains(query) || keywords.contains(where: { $0.contains(query) }) { return 3 }
        return nil
    }
}

private struct RankedEmoji {
    let entry: EmojiEntry
    let score: Int
    let originalIndex: Int
}
