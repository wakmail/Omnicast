// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation

public enum ClipboardCapturePolicy {
    public static let concealedTypeName = "org.nspasteboard.ConcealedType"
    public static let transientTypeName = "org.nspasteboard.TransientType"

    public static func shouldSkip(typeNames: [String]) -> Bool {
        let privateTypes = Set([
            concealedTypeName.lowercased(),
            transientTypeName.lowercased()
        ])
        return typeNames.contains { privateTypes.contains($0.lowercased()) }
    }
}

@MainActor
public final class ClipboardMonitor {
    public let pollInterval: TimeInterval
    public private(set) var isRunning = false
    public private(set) var lastError: Error?

    private let store: ClipboardHistoryStore
    private let pasteboard: NSPasteboard
    private let workspace: NSWorkspace
    private var lastChangeCount: Int
    private var timer: Timer?

    public init(
        store: ClipboardHistoryStore,
        pasteboard: NSPasteboard = .general,
        workspace: NSWorkspace = .shared,
        pollInterval: TimeInterval = 0.5
    ) {
        self.store = store
        self.pasteboard = pasteboard
        self.workspace = workspace
        self.pollInterval = pollInterval
        lastChangeCount = pasteboard.changeCount
    }

    public func start() {
        stop()
        lastChangeCount = pasteboard.changeCount
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollNow()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        isRunning = true
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    public func ignoreCurrentPasteboardContents() {
        lastChangeCount = pasteboard.changeCount
    }

    public func pollNow() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        let typeNames = pasteboard.types?.map(\.rawValue) ?? []
        guard !ClipboardCapturePolicy.shouldSkip(typeNames: typeNames) else { return }

        do {
            let sourceApplication = currentSourceApplication()
            if let fileURLs = readFileURLs(), !fileURLs.isEmpty {
                try store.recordFiles(fileURLs, sourceApplication: sourceApplication)
                lastError = nil
                return
            }
            if let image = readImage() {
                try store.recordImage(
                    pngData: image.data,
                    pixelWidth: image.width,
                    pixelHeight: image.height,
                    sourceApplication: sourceApplication
                )
                lastError = nil
                return
            }
            if let text = pasteboard.string(forType: .string) {
                try store.recordText(text, sourceApplication: sourceApplication)
                lastError = nil
            }
        } catch ClipboardHistoryError.emptyContent {
            lastError = nil
        } catch {
            lastError = error
        }
    }

    private func currentSourceApplication() -> ClipboardSourceApplication? {
        guard let application = workspace.frontmostApplication else { return nil }
        return ClipboardSourceApplication(
            bundleIdentifier: application.bundleIdentifier,
            name: application.localizedName
        )
    }

    private func readFileURLs() -> [URL]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) as? [NSURL] else { return nil }
        return objects.map { $0 as URL }
    }

    private func readImage() -> (data: Data, width: Int, height: Int)? {
        if let pngData = pasteboard.data(forType: .png),
           let image = NSImage(data: pngData) {
            let size = imagePixelSize(image, data: pngData)
            return (pngData, size.width, size.height)
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return (pngData, bitmap.pixelsWide, bitmap.pixelsHigh)
    }

    private func imagePixelSize(_ image: NSImage, data: Data) -> (width: Int, height: Int) {
        if let bitmap = NSBitmapImageRep(data: data) {
            return (bitmap.pixelsWide, bitmap.pixelsHigh)
        }
        return (Int(image.size.width), Int(image.size.height))
    }
}
