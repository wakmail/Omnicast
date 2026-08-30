// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

@MainActor
public final class QuicklinkStore: ObservableObject {
    @Published public private(set) var quicklinks: [Quicklink]
    public let fileURL: URL

    public init(directoryURL: URL = OmnicastDataDirectory.defaultURL) throws {
        fileURL = directoryURL.appendingPathComponent("quicklinks.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            quicklinks = try decoder.decode([Quicklink].self, from: data)
        } else {
            quicklinks = []
        }
        quicklinks.sort { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    public func create(
        name: String,
        urlTemplate: String,
        openWithAppBundleIdentifier: String? = nil,
        icon: String = "Globe",
        now: Date = Date()
    ) throws -> Quicklink {
        let normalized = try Self.normalizedValues(
            name: name,
            urlTemplate: urlTemplate,
            bundleIdentifier: openWithAppBundleIdentifier,
            icon: icon
        )
        let quicklink = Quicklink(
            name: normalized.name,
            urlTemplate: normalized.urlTemplate,
            openWithAppBundleIdentifier: normalized.bundleIdentifier,
            icon: normalized.icon,
            createdAt: now,
            updatedAt: now
        )
        quicklinks.insert(quicklink, at: 0)
        try save()
        return quicklink
    }

    @discardableResult
    public func update(
        id: UUID,
        name: String,
        urlTemplate: String,
        openWithAppBundleIdentifier: String? = nil,
        icon: String,
        now: Date = Date()
    ) throws -> Quicklink {
        guard let index = quicklinks.firstIndex(where: { $0.id == id }) else {
            throw QuicklinkError.notFound
        }
        let normalized = try Self.normalizedValues(
            name: name,
            urlTemplate: urlTemplate,
            bundleIdentifier: openWithAppBundleIdentifier,
            icon: icon
        )
        quicklinks[index].name = normalized.name
        quicklinks[index].urlTemplate = normalized.urlTemplate
        quicklinks[index].openWithAppBundleIdentifier = normalized.bundleIdentifier
        quicklinks[index].icon = normalized.icon
        quicklinks[index].updatedAt = now
        quicklinks.sort { $0.updatedAt > $1.updatedAt }
        try save()
        return quicklinks.first(where: { $0.id == id })!
    }

    public func delete(id: UUID) throws {
        guard let index = quicklinks.firstIndex(where: { $0.id == id }) else {
            throw QuicklinkError.notFound
        }
        quicklinks.remove(at: index)
        try save()
    }

    @discardableResult
    public func importRaycastExport(data: Data, now: Date = Date()) throws -> QuicklinkImportResult {
        let object = try JSONSerialization.jsonObject(with: data)
        let records = Self.raycastRecords(from: object)
        var imported = 0
        var skipped = 0
        var failed = 0
        var existing = Set(quicklinks.map(Self.deduplicationKey))

        for record in records {
            guard let name = record["name"] as? String,
                  let rawURL = record["url"] as? String
            else {
                failed += 1
                continue
            }
            let template = rawURL.replacingOccurrences(
                of: "{argument}",
                with: "{query}",
                options: .caseInsensitive
            )
            let normalized: (name: String, urlTemplate: String, bundleIdentifier: String?, icon: String)
            do {
                normalized = try Self.normalizedValues(
                    name: name,
                    urlTemplate: template,
                    bundleIdentifier: nil,
                    icon: template.localizedCaseInsensitiveContains("{query}") ? "Search" : "Globe"
                )
            } catch {
                failed += 1
                continue
            }
            let key = Self.deduplicationKey(
                name: normalized.name,
                urlTemplate: normalized.urlTemplate
            )
            guard existing.insert(key).inserted else {
                skipped += 1
                continue
            }
            let importedID = (record["uuid"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
            quicklinks.append(
                Quicklink(
                    id: importedID,
                    name: normalized.name,
                    urlTemplate: normalized.urlTemplate,
                    icon: normalized.icon,
                    createdAt: now,
                    updatedAt: now
                )
            )
            imported += 1
        }
        quicklinks.sort { $0.updatedAt > $1.updatedAt }
        if imported > 0 {
            try save()
        }
        return QuicklinkImportResult(
            found: records.count,
            imported: imported,
            skipped: skipped,
            failed: failed
        )
    }

    private func save() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(quicklinks).write(to: fileURL, options: .atomic)
    }

    private static func normalizedValues(
        name: String,
        urlTemplate: String,
        bundleIdentifier: String?,
        icon: String
    ) throws -> (name: String, urlTemplate: String, bundleIdentifier: String?, icon: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw QuicklinkError.missingName }
        let template = urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !template.isEmpty else { throw QuicklinkError.missingURLTemplate }
        let candidate = template.replacingOccurrences(
            of: "{query}",
            with: "query",
            options: .caseInsensitive
        )
        guard URL(string: candidate) != nil else { throw QuicklinkError.invalidURLTemplate }
        let bundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let icon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            name,
            template,
            bundleIdentifier?.isEmpty == false ? bundleIdentifier : nil,
            icon.isEmpty ? "Globe" : String(icon.prefix(80))
        )
    }

    private static func raycastRecords(from object: Any) -> [[String: Any]] {
        if let records = object as? [[String: Any]] {
            return records
        }
        guard let dictionary = object as? [String: Any] else { return [] }
        if let records = dictionary["quicklinks"] as? [[String: Any]] {
            return records
        }
        if let package = dictionary["builtin_package_quicklinks"] as? [String: Any],
           let records = package["quicklinks"] as? [[String: Any]] {
            return records
        }
        return []
    }

    private static func deduplicationKey(_ quicklink: Quicklink) -> String {
        deduplicationKey(name: quicklink.name, urlTemplate: quicklink.urlTemplate)
    }

    private static func deduplicationKey(name: String, urlTemplate: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            + "::"
            + urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
