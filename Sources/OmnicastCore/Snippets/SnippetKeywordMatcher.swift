// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct SnippetKeywordMatch: Equatable, Sendable {
    public let keyword: String
    public let delimiter: String

    public init(keyword: String, delimiter: String) {
        self.keyword = keyword
        self.delimiter = delimiter
    }
}

public struct SnippetKeywordMatcher: Sendable {
    private var keywords: Set<String> = []
    private var sortedKeywords: [String] = []
    private var maxKeywordLength = 1
    private var allowedCharacters = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "-_")
    )
    private var delimiters = CharacterSet.whitespacesAndNewlines.union(
        CharacterSet(charactersIn: ".,!?;:()[]{}<>/\\|@#$%^&*+=`~\"'")
    )
    private var currentToken = ""

    public init(keywords: [String]) {
        updateKeywords(keywords)
    }

    public mutating func updateKeywords(_ newKeywords: [String]) {
        keywords = Set(newKeywords.map { $0.lowercased() })
        sortedKeywords = keywords.sorted { $0.count > $1.count }
        maxKeywordLength = max(sortedKeywords.first?.count ?? 1, 1)
        allowedCharacters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-_")
        )
        delimiters = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: ".,!?;:()[]{}<>/\\|@#$%^&*+=`~\"'")
        )
        for keyword in keywords {
            for scalar in keyword.unicodeScalars where !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                allowedCharacters.insert(scalar)
                delimiters.remove(scalar)
            }
        }
        currentToken = ""
    }

    public mutating func process(_ character: Character) -> SnippetKeywordMatch? {
        if isMember(character, of: allowedCharacters) {
            currentToken.append(contentsOf: String(character).lowercased())
            if currentToken.count > maxKeywordLength {
                currentToken = String(currentToken.suffix(maxKeywordLength))
            }
            if let keyword = sortedKeywords.first(where: { currentToken == $0 }) {
                currentToken = ""
                return SnippetKeywordMatch(keyword: keyword, delimiter: "")
            }
            return nil
        }

        if isMember(character, of: delimiters) {
            defer { currentToken = "" }
            if !currentToken.isEmpty, keywords.contains(currentToken) {
                return SnippetKeywordMatch(keyword: currentToken, delimiter: String(character))
            }
            return nil
        }

        currentToken = ""
        return nil
    }

    public mutating func processBackspace() {
        if !currentToken.isEmpty {
            currentToken.removeLast()
        }
    }

    public mutating func reset() {
        currentToken = ""
    }

    private func isMember(_ character: Character, of set: CharacterSet) -> Bool {
        !character.unicodeScalars.isEmpty
            && character.unicodeScalars.allSatisfy { set.contains($0) }
    }
}
