// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

@MainActor
public final class SnippetStore: ObservableObject {
    @Published public private(set) var snippets: [Snippet]
    public let fileURL: URL

    public init(directoryURL: URL = OmnicastDataDirectory.defaultURL) throws {
        fileURL = directoryURL.appendingPathComponent("snippets.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            snippets = try JSONDecoder.snippetDecoder.decode([Snippet].self, from: data)
        } else {
            snippets = []
        }
        sortSnippets()
    }

    @discardableResult
    public func create(
        name: String,
        keyword: String? = nil,
        content: String,
        at date: Date = Date()
    ) throws -> Snippet {
        let snippet = Snippet(
            name: try normalizedName(name),
            keyword: try normalizedKeyword(keyword),
            content: try validatedContent(content),
            created: date
        )
        snippets.append(snippet)
        sortSnippets()
        try save()
        return snippet
    }

    @discardableResult
    public func update(
        id: UUID,
        name: String,
        keyword: String?,
        content: String
    ) throws -> Snippet? {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else { return nil }
        snippets[index].name = try normalizedName(name)
        snippets[index].keyword = try normalizedKeyword(keyword)
        snippets[index].content = try validatedContent(content)
        let updated = snippets[index]
        try save()
        return updated
    }

    @discardableResult
    public func delete(id: UUID) throws -> Bool {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else { return false }
        snippets.remove(at: index)
        try save()
        return true
    }

    @discardableResult
    public func recordUse(id: UUID, at date: Date = Date()) throws -> Snippet? {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else { return nil }
        snippets[index].lastUsed = date
        let used = snippets[index]
        sortSnippets()
        try save()
        return used
    }

    public func snippet(id: UUID) -> Snippet? {
        snippets.first { $0.id == id }
    }

    public func snippet(keyword: String) -> Snippet? {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return nil }
        return snippets.first {
            $0.keyword?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == query
        }
    }

    public func search(_ query: String) -> [Snippet] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return snippets }
        return snippets.filter { snippet in
            snippet.name.localizedCaseInsensitiveContains(needle)
                || snippet.content.localizedCaseInsensitiveContains(needle)
                || snippet.keyword?.localizedCaseInsensitiveContains(needle) == true
        }
    }

    @discardableResult
    public func importRaycastJSON(_ data: Data, at date: Date = Date()) throws -> SnippetImportResult {
        let items = try Self.decodeImportItems(data)
        var imported = 0
        var skipped = 0
        var failed = 0

        for item in items {
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = item.content
            guard !name.isEmpty, !content.isEmpty else {
                failed += 1
                continue
            }
            let keyword = Self.normalizedStoredKeyword(item.keyword)
            let duplicate = snippets.contains { existing in
                existing.name.caseInsensitiveCompare(name) == .orderedSame
                    || Self.keywordsMatch(existing.keyword, keyword)
            }
            if duplicate {
                skipped += 1
                continue
            }
            snippets.append(Snippet(
                name: name,
                keyword: keyword,
                content: content,
                created: date
            ))
            imported += 1
        }

        if imported > 0 {
            sortSnippets()
            try save()
        }
        return SnippetImportResult(imported: imported, skipped: skipped, failed: failed)
    }

    @discardableResult
    public func importRaycastJSON(at url: URL, date: Date = Date()) throws -> SnippetImportResult {
        try importRaycastJSON(Data(contentsOf: url), at: date)
    }

    private func normalizedName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw SnippetStoreError.emptyName }
        return value
    }

    private func validatedContent(_ content: String) throws -> String {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SnippetStoreError.emptyContent
        }
        return content
    }

    private func normalizedKeyword(_ keyword: String?) throws -> String? {
        guard let keyword else { return nil }
        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.contains(where: { $0 == "\"" || $0 == "'" || $0 == "`" }) {
            throw SnippetStoreError.invalidKeyword
        }
        return value
    }

    private static func normalizedStoredKeyword(_ keyword: String?) -> String? {
        guard let keyword else { return nil }
        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        guard !value.contains(where: { $0 == "\"" || $0 == "'" || $0 == "`" }) else {
            return nil
        }
        return value
    }

    private static func keywordsMatch(_ first: String?, _ second: String?) -> Bool {
        guard let first, let second else { return false }
        return first.caseInsensitiveCompare(second) == .orderedSame
    }

    private func sortSnippets() {
        snippets.sort { first, second in
            switch (first.lastUsed, second.lastUsed) {
            case let (left?, right?):
                if left != right { return left > right }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }
            if first.created != second.created { return first.created > second.created }
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
    }

    private func save() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder.snippetEncoder.encode(snippets).write(to: fileURL, options: .atomic)
    }

    private struct ImportItem: Decodable {
        let name: String
        let content: String
        let keyword: String?

        private enum CodingKeys: String, CodingKey {
            case name
            case content
            case text
            case keyword
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            content = try container.decodeIfPresent(String.self, forKey: .content)
                ?? container.decodeIfPresent(String.self, forKey: .text)
                ?? ""
            keyword = try container.decodeIfPresent(String.self, forKey: .keyword)
        }
    }

    private struct SnippetWrapper: Decodable {
        let snippets: [ImportItem]
    }

    private struct RaycastPackage: Decodable {
        let snippets: [ImportItem]
    }

    private struct RaycastBackup: Decodable {
        let package: RaycastPackage?

        private enum CodingKeys: String, CodingKey {
            case package = "builtin_package_snippets"
        }
    }

    private static func decodeImportItems(_ data: Data) throws -> [ImportItem] {
        let decoder = JSONDecoder()
        if let items = try? decoder.decode([ImportItem].self, from: data) {
            return items
        }
        if let wrapper = try? decoder.decode(SnippetWrapper.self, from: data) {
            return wrapper.snippets
        }
        if let backup = try? decoder.decode(RaycastBackup.self, from: data), let package = backup.package {
            return package.snippets
        }
        throw SnippetStoreError.invalidImport
    }
}

private extension JSONEncoder {
    static var snippetEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var snippetDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
