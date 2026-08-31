// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation

public actor IconDiskCache {
    public static let shared = IconDiskCache()

    private struct Entry {
        let url: URL
        let byteCount: Int
        let modificationDate: Date
    }

    private let directoryURL: URL
    private let maximumFileCount: Int
    private let maximumByteCount: Int
    private let fileManager: FileManager

    public init(
        directoryURL: URL = OmnicastDataDirectory.defaultURL
            .appendingPathComponent("icon-cache", isDirectory: true),
        maximumFileCount: Int = 500,
        maximumByteCount: Int = 50 * 1_024 * 1_024,
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL
        self.maximumFileCount = max(0, maximumFileCount)
        self.maximumByteCount = max(0, maximumByteCount)
        self.fileManager = fileManager
    }

    public func data(for url: URL) -> Data? {
        let fileURL = cachedFileURL(for: url)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
        return data
    }

    public func store(_ data: Data, for url: URL) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try data.write(to: cachedFileURL(for: url), options: .atomic)
        try evictIfNeeded()
    }

    public static func cacheKey(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func cachedFileURL(for url: URL) -> URL {
        directoryURL.appendingPathComponent(Self.cacheKey(for: url))
    }

    private func evictIfNeeded() throws {
        var entries = try cacheEntries().sorted {
            if $0.modificationDate == $1.modificationDate {
                return $0.url.lastPathComponent < $1.url.lastPathComponent
            }
            return $0.modificationDate < $1.modificationDate
        }
        var totalBytes = entries.reduce(0) { $0 + $1.byteCount }

        while entries.count > maximumFileCount || totalBytes > maximumByteCount {
            let entry = entries.removeFirst()
            try fileManager.removeItem(at: entry.url)
            totalBytes -= entry.byteCount
        }
    }

    private func cacheEntries() throws -> [Entry] {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return [] }
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]
        return try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ).compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                return nil
            }
            return Entry(
                url: url,
                byteCount: values.fileSize ?? 0,
                modificationDate: values.contentModificationDate ?? .distantPast
            )
        }
    }
}
