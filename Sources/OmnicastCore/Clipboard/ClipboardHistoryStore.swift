// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

@MainActor
public final class ClipboardHistoryStore: ObservableObject {
    public static let maximumUnpinnedItemCount = 500
    public static let maximumImageByteCount = 10 * 1024 * 1024

    @Published public private(set) var items: [ClipboardItem]

    public let directoryURL: URL
    public let indexFileURL: URL
    public let imagesDirectoryURL: URL

    private let fileManager: FileManager

    public init(
        directoryURL: URL = OmnicastDataDirectory.defaultURL,
        fileManager: FileManager = .default
    ) throws {
        self.directoryURL = directoryURL.appendingPathComponent("Clipboard", isDirectory: true)
        indexFileURL = self.directoryURL.appendingPathComponent("history.json")
        imagesDirectoryURL = self.directoryURL.appendingPathComponent("Images", isDirectory: true)
        self.fileManager = fileManager
        items = []

        guard fileManager.fileExists(atPath: indexFileURL.path) else { return }
        let data = try Data(contentsOf: indexFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        items = try decoder.decode([ClipboardItem].self, from: data)
        let originalItems = items
        items.removeAll { item in
            item.kind == .image && !imageFileExists(for: item)
        }
        sortItems()
        enforceLimit()
        if items != originalItems {
            try save()
        }
    }

    @discardableResult
    public func recordText(
        _ text: String,
        sourceApplication: ClipboardSourceApplication? = nil,
        createdAt: Date = Date()
    ) throws -> ClipboardItem {
        let normalizedText = ClipboardTextContent.normalized(text)
        guard !normalizedText.isEmpty else { throw ClipboardHistoryError.emptyContent }
        guard normalizedText.count <= ClipboardTextContent.maximumLength else {
            throw ClipboardHistoryError.textTooLarge
        }

        if let recentIndex = mostRecentCaptureIndex,
           items[recentIndex].kind == .text,
           items[recentIndex].textContent == normalizedText {
            var updatedItem = items[recentIndex]
            updatedItem.previewText = ClipboardTextContent.preview(for: normalizedText)
            updatedItem.sourceApplication = sourceApplication
            updatedItem.createdAt = createdAt
            items[recentIndex] = updatedItem
            sortItems()
            try save()
            return updatedItem
        }

        let item = ClipboardItem(
            kind: .text,
            previewText: ClipboardTextContent.preview(for: normalizedText),
            textContent: normalizedText,
            sourceApplication: sourceApplication,
            createdAt: createdAt
        )
        try insert(item)
        return item
    }

    @discardableResult
    public func recordImage(
        pngData: Data,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        sourceApplication: ClipboardSourceApplication? = nil,
        createdAt: Date = Date()
    ) throws -> ClipboardItem {
        guard !pngData.isEmpty else { throw ClipboardHistoryError.emptyContent }
        guard pngData.count <= Self.maximumImageByteCount else {
            throw ClipboardHistoryError.imageTooLarge
        }

        try fileManager.createDirectory(
            at: imagesDirectoryURL,
            withIntermediateDirectories: true
        )
        let id = UUID()
        let imageURL = imagesDirectoryURL.appendingPathComponent("\(id.uuidString).png")
        try pngData.write(to: imageURL, options: .atomic)

        let dimensions: String
        if let pixelWidth, let pixelHeight {
            dimensions = " \(pixelWidth) × \(pixelHeight)"
        } else {
            dimensions = ""
        }
        let item = ClipboardItem(
            id: id,
            kind: .image,
            previewText: "Image\(dimensions)",
            imageFilePath: imageURL.path,
            imageWidth: pixelWidth,
            imageHeight: pixelHeight,
            sourceApplication: sourceApplication,
            createdAt: createdAt
        )

        do {
            try insert(item)
        } catch {
            try? fileManager.removeItem(at: imageURL)
            throw error
        }
        return item
    }

    @discardableResult
    public func recordFiles(
        _ urls: [URL],
        sourceApplication: ClipboardSourceApplication? = nil,
        createdAt: Date = Date()
    ) throws -> ClipboardItem {
        var seen = Set<URL>()
        let fileURLs = urls.filter { $0.isFileURL && seen.insert($0.standardizedFileURL).inserted }
        guard !fileURLs.isEmpty else { throw ClipboardHistoryError.noFiles }
        let names = fileURLs.map { url in
            url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        }
        let item = ClipboardItem(
            kind: .files,
            previewText: ClipboardTextContent.preview(for: names.joined(separator: ", ")),
            fileURLs: fileURLs,
            sourceApplication: sourceApplication,
            createdAt: createdAt
        )
        try insert(item)
        return item
    }

    public func search(_ query: String) -> [ClipboardItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return items }
        return items.filter { item in
            item.previewText.range(
                of: normalizedQuery,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }

    @discardableResult
    public func togglePin(id: UUID) throws -> ClipboardItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        items[index].isPinned.toggle()
        let changedID = items[index].id
        sortItems()
        enforceLimit()
        try save()
        return items.first { $0.id == changedID }
    }

    @discardableResult
    public func delete(id: UUID) throws -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        let removed = items.remove(at: index)
        removeImageFile(for: removed)
        try save()
        return true
    }

    public func clear() throws {
        for item in items {
            removeImageFile(for: item)
        }
        items = []
        try save()
    }

    private var mostRecentCaptureIndex: Int? {
        items.indices.max { left, right in
            items[left].createdAt < items[right].createdAt
        }
    }

    private func insert(_ item: ClipboardItem) throws {
        items.append(item)
        sortItems()
        enforceLimit()
        try save()
    }

    private func sortItems() {
        items.sort { left, right in
            if left.isPinned != right.isPinned {
                return left.isPinned
            }
            if left.createdAt != right.createdAt {
                return left.createdAt > right.createdAt
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private func enforceLimit() {
        let unpinned = items
            .filter { !$0.isPinned }
            .sorted { $0.createdAt > $1.createdAt }
        guard unpinned.count > Self.maximumUnpinnedItemCount else { return }
        let removedIDs = Set(unpinned.dropFirst(Self.maximumUnpinnedItemCount).map(\.id))
        let removedItems = items.filter { removedIDs.contains($0.id) }
        items.removeAll { removedIDs.contains($0.id) }
        for item in removedItems {
            removeImageFile(for: item)
        }
    }

    private func imageFileExists(for item: ClipboardItem) -> Bool {
        guard let path = item.imageFilePath else { return false }
        return fileManager.fileExists(atPath: path)
    }

    private func removeImageFile(for item: ClipboardItem) {
        guard item.kind == .image,
              let path = item.imageFilePath,
              isManagedImagePath(path) else { return }
        try? fileManager.removeItem(atPath: path)
    }

    private func isManagedImagePath(_ path: String) -> Bool {
        let imagesPath = imagesDirectoryURL.standardizedFileURL.path + "/"
        let candidatePath = URL(fileURLWithPath: path).standardizedFileURL.path
        return candidatePath.hasPrefix(imagesPath)
    }

    private func save() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        try encoder.encode(items).write(to: indexFileURL, options: .atomic)
    }
}

public enum ClipboardHistoryError: LocalizedError, Equatable {
    case emptyContent
    case textTooLarge
    case imageTooLarge
    case noFiles

    public var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "Clipboard content is empty"
        case .textTooLarge:
            return "Clipboard text is too large"
        case .imageTooLarge:
            return "Clipboard image is too large"
        case .noFiles:
            return "The clipboard has no file URLs"
        }
    }
}
