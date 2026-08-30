// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore

public actor ExtensionPersistence {
    private let localStorageDirectoryURL: URL
    private let preferencesDirectoryURL: URL
    private let fileManager: FileManager

    public init(
        directoryURL: URL = OmnicastDataDirectory.defaultURL,
        fileManager: FileManager = .default
    ) {
        localStorageDirectoryURL = directoryURL.appendingPathComponent(
            "extension-storage",
            isDirectory: true
        )
        preferencesDirectoryURL = directoryURL.appendingPathComponent(
            "extension-preferences",
            isDirectory: true
        )
        self.fileManager = fileManager
    }

    public func localStorage(extensionSlug: String) throws -> [String: JSONValue] {
        try load(from: storageURL(extensionSlug))
    }

    public func setLocalStorageValue(
        _ value: JSONValue,
        forKey key: String,
        extensionSlug: String
    ) throws {
        let url = storageURL(extensionSlug)
        var values = try load(from: url)
        values[key] = value
        try save(values, to: url)
    }

    public func removeLocalStorageValue(forKey key: String, extensionSlug: String) throws {
        let url = storageURL(extensionSlug)
        var values = try load(from: url)
        values.removeValue(forKey: key)
        try save(values, to: url)
    }

    public func clearLocalStorage(extensionSlug: String) throws {
        try save([:], to: storageURL(extensionSlug))
    }

    public func preferences(extensionSlug: String) throws -> [String: JSONValue] {
        try load(from: preferencesURL(extensionSlug))
    }

    public func setPreferences(
        _ values: [String: JSONValue],
        extensionSlug: String
    ) throws {
        try save(values, to: preferencesURL(extensionSlug))
    }

    private func storageURL(_ slug: String) -> URL {
        localStorageDirectoryURL.appendingPathComponent("\(safeFileName(slug)).json")
    }

    private func preferencesURL(_ slug: String) -> URL {
        preferencesDirectoryURL.appendingPathComponent("\(safeFileName(slug)).json")
    }

    private func safeFileName(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return input.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
    }

    private func load(from url: URL) throws -> [String: JSONValue] {
        guard fileManager.fileExists(atPath: url.path) else { return [:] }
        return try JSONDecoder().decode(
            [String: JSONValue].self,
            from: Data(contentsOf: url)
        )
    }

    private func save(_ values: [String: JSONValue], to url: URL) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(values).write(to: url, options: .atomic)
    }
}
