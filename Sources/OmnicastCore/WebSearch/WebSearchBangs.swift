// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct WebSearchBang: Equatable, Sendable {
    public let key: String
    public let aliases: [String]
    public let name: String
    public let host: String
    public let category: String
    public let urlTemplate: String

    public init(
        key: String,
        aliases: [String] = [],
        name: String,
        host: String,
        category: String,
        urlTemplate: String
    ) {
        self.key = key
        self.aliases = aliases
        self.name = name
        self.host = host
        self.category = category
        self.urlTemplate = urlTemplate
    }
}

public struct WebSearchBangs: Sendable {
    public let bangs: [WebSearchBang]
    public let defaultSearchURLTemplate: String
    private let lookup: [String: WebSearchBang]

    public init(
        bangs: [WebSearchBang] = WebSearchBangs.defaultBangs,
        defaultSearchURLTemplate: String = "https://duckduckgo.com/?q={query}"
    ) {
        self.bangs = bangs
        self.defaultSearchURLTemplate = defaultSearchURLTemplate
        var lookup: [String: WebSearchBang] = [:]
        for bang in bangs {
            lookup[Self.normalizeKey(bang.key)] = bang
            for alias in bang.aliases {
                lookup[Self.normalizeKey(alias)] = bang
            }
        }
        self.lookup = lookup
    }

    public func resolve(query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let pieces = trimmed.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { $0.isWhitespace }
        )
        if let first = pieces.first, first.hasPrefix("!") {
            let key = Self.normalizeKey(String(first))
            if let bang = lookup[key] {
                let search = pieces.count > 1 ? String(pieces[1]) : ""
                return Self.makeURL(template: bang.urlTemplate, query: search)
            }
        }
        return Self.makeURL(template: defaultSearchURLTemplate, query: trimmed)
    }

    public func bang(for key: String) -> WebSearchBang? {
        lookup[Self.normalizeKey(key)]
    }

    public static let defaultBangs: [WebSearchBang] = [
        WebSearchBang(
            key: "g",
            aliases: ["google"],
            name: "Google",
            host: "google.com",
            category: "Search",
            urlTemplate: "https://www.google.com/search?q={query}"
        ),
        WebSearchBang(
            key: "ddg",
            aliases: ["d", "duckduckgo"],
            name: "DuckDuckGo",
            host: "duckduckgo.com",
            category: "Search",
            urlTemplate: "https://duckduckgo.com/?q={query}"
        ),
        WebSearchBang(
            key: "yt",
            aliases: ["youtube"],
            name: "YouTube",
            host: "youtube.com",
            category: "Multimedia",
            urlTemplate: "https://www.youtube.com/results?search_query={query}"
        ),
        WebSearchBang(
            key: "gh",
            aliases: ["github"],
            name: "GitHub",
            host: "github.com",
            category: "Programming",
            urlTemplate: "https://github.com/search?q={query}"
        ),
        WebSearchBang(
            key: "npm",
            name: "npm",
            host: "npmjs.com",
            category: "Programming",
            urlTemplate: "https://www.npmjs.com/search?q={query}"
        ),
        WebSearchBang(
            key: "mdn",
            name: "MDN",
            host: "developer.mozilla.org",
            category: "Programming",
            urlTemplate: "https://developer.mozilla.org/search?q={query}"
        ),
        WebSearchBang(
            key: "maps",
            aliases: ["gm"],
            name: "Google Maps",
            host: "google.com",
            category: "Search",
            urlTemplate: "https://www.google.com/maps/search/{query}"
        ),
        WebSearchBang(
            key: "img",
            aliases: ["image", "images", "gi", "gim", "gimg", "gimages"],
            name: "Google Images",
            host: "google.com",
            category: "Search",
            urlTemplate: "https://www.google.com/search?tbm=isch&q={query}"
        ),
        WebSearchBang(
            key: "wiki",
            aliases: ["w", "wikipedia"],
            name: "Wikipedia",
            host: "wikipedia.org",
            category: "Reference",
            urlTemplate: "https://en.wikipedia.org/w/index.php?search={query}"
        ),
        WebSearchBang(
            key: "x",
            aliases: ["twitter"],
            name: "X",
            host: "x.com",
            category: "Social",
            urlTemplate: "https://x.com/search?q={query}"
        )
    ]

    private static func normalizeKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .drop(while: { $0 == "!" })
            .filter { $0.isLetter || $0.isNumber || ".+_".contains($0) }
    }

    private static func makeURL(template: String, query: String) -> URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        return URL(string: template.replacingOccurrences(of: "{query}", with: encoded))
    }
}
