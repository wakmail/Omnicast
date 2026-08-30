// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

public struct ColorHistoryItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let hex: String
    public let createdAt: Date

    public init(id: UUID = UUID(), hex: String, createdAt: Date = Date()) {
        self.id = id
        self.hex = hex
        self.createdAt = createdAt
    }
}

@MainActor
public final class ColorHistoryStore: ObservableObject {
    public static let maximumItemCount = 24

    @Published public private(set) var items: [ColorHistoryItem]

    public let directoryURL: URL
    public let fileURL: URL

    private let fileManager: FileManager

    public init(
        directoryURL: URL = OmnicastDataDirectory.defaultURL,
        fileManager: FileManager = .default
    ) throws {
        self.directoryURL = directoryURL.appendingPathComponent("ColorPicker", isDirectory: true)
        fileURL = self.directoryURL.appendingPathComponent("history.json")
        self.fileManager = fileManager
        items = []

        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        items = try decoder.decode([ColorHistoryItem].self, from: Data(contentsOf: fileURL))
    }

    @discardableResult
    public func record(hex: String, createdAt: Date = Date()) throws -> ColorHistoryItem {
        let normalized = Self.normalizedHex(hex)
        items.removeAll { $0.hex == normalized }
        let item = ColorHistoryItem(hex: normalized, createdAt: createdAt)
        items.insert(item, at: 0)
        items = Array(items.prefix(Self.maximumItemCount))
        try save()
        return item
    }

    public func clear() throws {
        items = []
        try save()
    }

    public static func normalizedHex(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
    }

    private func save() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(items).write(to: fileURL, options: .atomic)
    }
}
