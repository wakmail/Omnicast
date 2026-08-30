// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct WebSearchFallbackCommand: Command {
    public let query: String
    public let targetName: String?
    public let url: URL

    public let id = "web-search-fallback"
    public var title: String {
        if let targetName {
            let terms = Self.bangTerms(query)
            return terms.isEmpty
                ? "Search \(targetName)"
                : "Search \(targetName) for \(terms)"
        }
        return "Search the web for \(query.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
    public var subtitle: String { url.host ?? "Web Search" }
    public let icon: CommandIcon = .sfSymbol("globe")
    public let keywords = ["web", "search"]
    public let kind: CommandKind = .system
    public var resourceURL: URL? { url }

    public init?(query: String, bangs: WebSearchBangs = WebSearchBangs()) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, let url = bangs.resolve(query: normalized) else { return nil }
        self.query = normalized
        self.url = url
        let first = normalized.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
        targetName = first.hasPrefix("!") ? bangs.bang(for: first)?.name : nil
    }

    @MainActor
    public func execute(context: CommandContext) async throws {
        try await context.opener.open(url)
    }

    private static func bangTerms(_ query: String) -> String {
        let pieces = query.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { $0.isWhitespace }
        )
        return pieces.count > 1 ? String(pieces[1]) : ""
    }
}

public enum LauncherSearchResults {
    public static func resolve(
        commands: [any Command],
        query: String,
        frecency: [String: FrecencyEntry] = [:],
        bangs: WebSearchBangs = WebSearchBangs()
    ) -> [RankedCommand] {
        let ranked = SearchRanker.rank(commands, query: query, frecency: frecency)
        guard ranked.isEmpty, let fallback = WebSearchFallbackCommand(query: query, bangs: bangs) else {
            return ranked
        }
        return [RankedCommand(command: fallback, score: 0)]
    }
}
