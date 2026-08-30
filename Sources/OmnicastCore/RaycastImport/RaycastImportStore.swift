// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@MainActor
public final class RaycastImportStore {
    public let fileURL: URL
    public let extensionPreferencesDirectoryURL: URL
    public private(set) var data: RaycastSupplementalImportData

    public init(directoryURL: URL = OmnicastDataDirectory.defaultURL) throws {
        fileURL = directoryURL.appendingPathComponent("raycastImport.json")
        extensionPreferencesDirectoryURL = directoryURL.appendingPathComponent(
            "extension-preferences",
            isDirectory: true
        )
        if FileManager.default.fileExists(atPath: fileURL.path) {
            data = try JSONDecoder().decode(
                RaycastSupplementalImportData.self,
                from: Data(contentsOf: fileURL)
            )
        } else {
            data = RaycastSupplementalImportData()
        }
    }

    public func mergeScriptDirectories(_ directories: [String]) throws -> Int {
        var existing = Set(data.scriptDirectories)
        let priorCount = existing.count
        for directory in directories {
            existing.insert(directory)
        }
        data.scriptDirectories = existing.sorted()
        if existing.count != priorCount {
            try save()
        }
        return existing.count - priorCount
    }

    public func setCommandHotkey(
        _ hotkey: RaycastImportedCommandHotkey,
        commandKey: String
    ) throws -> Bool {
        guard data.commandHotkeys[commandKey] == nil else { return false }
        data.commandHotkeys[commandKey] = hotkey
        try save()
        return true
    }

    public func mergeDisabledCommandKeys(_ keys: [String]) throws -> Int {
        var existing = Set(data.disabledCommandKeys)
        let priorCount = existing.count
        for key in keys {
            existing.insert(key)
        }
        data.disabledCommandKeys = existing.sorted()
        if existing.count != priorCount {
            try save()
        }
        return existing.count - priorCount
    }

    public func mergeExtensionPreferences(
        _ values: [String: RaycastJSONValue],
        extensionSlug: String
    ) throws -> Int {
        let url = preferenceURL(extensionSlug)
        var existing: [String: RaycastJSONValue]
        if FileManager.default.fileExists(atPath: url.path) {
            existing = try JSONDecoder().decode(
                [String: RaycastJSONValue].self,
                from: Data(contentsOf: url)
            )
        } else {
            existing = [:]
        }
        let priorCount = existing.count
        for (key, value) in values where existing[key] == nil {
            existing[key] = value
        }
        let imported = existing.count - priorCount
        if imported > 0 {
            try FileManager.default.createDirectory(
                at: extensionPreferencesDirectoryURL,
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(existing).write(to: url, options: .atomic)
        }
        return imported
    }

    public func extensionPreferences(extensionSlug: String) throws -> [String: RaycastJSONValue] {
        let url = preferenceURL(extensionSlug)
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        return try JSONDecoder().decode(
            [String: RaycastJSONValue].self,
            from: Data(contentsOf: url)
        )
    }

    private func preferenceURL(_ slug: String) -> URL {
        extensionPreferencesDirectoryURL.appendingPathComponent("\(safeFileName(slug)).json")
    }

    private func safeFileName(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return input.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
    }

    private func save() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: fileURL, options: .atomic)
    }
}
