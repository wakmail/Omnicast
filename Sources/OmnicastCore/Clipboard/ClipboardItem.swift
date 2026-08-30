// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum ClipboardItemKind: String, Codable, CaseIterable, Sendable {
    case text
    case image
    case files
}

public struct ClipboardSourceApplication: Codable, Equatable, Sendable {
    public let bundleIdentifier: String?
    public let name: String?

    public init(bundleIdentifier: String?, name: String?) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }
}

public struct ClipboardItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let kind: ClipboardItemKind
    public var previewText: String
    public let textContent: String?
    public let imageFilePath: String?
    public let fileURLs: [URL]
    public let imageWidth: Int?
    public let imageHeight: Int?
    public var sourceApplication: ClipboardSourceApplication?
    public var createdAt: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        kind: ClipboardItemKind,
        previewText: String,
        textContent: String? = nil,
        imageFilePath: String? = nil,
        fileURLs: [URL] = [],
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        sourceApplication: ClipboardSourceApplication? = nil,
        createdAt: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.previewText = previewText
        self.textContent = textContent
        self.imageFilePath = imageFilePath
        self.fileURLs = fileURLs
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.sourceApplication = sourceApplication
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    public var imageURL: URL? {
        imageFilePath.map { URL(fileURLWithPath: $0) }
    }

    public var fullPreviewText: String {
        switch kind {
        case .text:
            return textContent ?? previewText
        case .image:
            return previewText
        case .files:
            return fileURLs.map(\.path).joined(separator: "\n")
        }
    }
}

public enum ClipboardTextContent {
    public static let maximumLength = 100_000
    public static let previewLength = 200

    public static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func preview(for text: String) -> String {
        let normalizedText = normalized(text)
        guard normalizedText.count > previewLength else { return normalizedText }
        return String(normalizedText.prefix(previewLength)) + "…"
    }
}
