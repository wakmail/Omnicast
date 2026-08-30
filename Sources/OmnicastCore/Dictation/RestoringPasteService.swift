// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

public struct PasteboardSnapshot: Equatable, Sendable {
    public struct Item: Equatable, Sendable {
        public var values: [String: Data]

        public init(values: [String: Data]) {
            self.values = values
        }
    }

    public var items: [Item]

    public init(items: [Item]) {
        self.items = items
    }
}

@MainActor
public protocol RestorablePasteboard: AnyObject {
    func snapshot() -> PasteboardSnapshot
    func writeString(_ text: String) -> Bool
    func restore(_ snapshot: PasteboardSnapshot)
}

@MainActor
public protocol PasteKeyboardEventPosting: AnyObject {
    func postPaste() throws
}

@MainActor
public final class SystemRestorablePasteboard: RestorablePasteboard {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func snapshot() -> PasteboardSnapshot {
        let items: [PasteboardSnapshot.Item] = pasteboard.pasteboardItems?.map { item in
            var values: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    values[type.rawValue] = data
                }
            }
            return PasteboardSnapshot.Item(values: values)
        } ?? []
        return PasteboardSnapshot(items: items)
    }

    public func writeString(_ text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    public func restore(_ snapshot: PasteboardSnapshot) {
        pasteboard.clearContents()
        let items = snapshot.items.map { snapshotItem in
            let item = NSPasteboardItem()
            for (rawType, data) in snapshotItem.values {
                item.setData(data, forType: NSPasteboard.PasteboardType(rawType))
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}

@MainActor
public final class SystemPasteKeyboardEventPoster: PasteKeyboardEventPosting {
    public init() {}

    public func postPaste() throws {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
              ),
              let up = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
              ) else {
            throw RestoringPasteError.couldNotCreateEvents
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

@MainActor
public final class RestoringPasteService {
    private let pasteboard: any RestorablePasteboard
    private let eventPoster: any PasteKeyboardEventPosting
    private let restorationDelay: UInt64

    public init(
        pasteboard: (any RestorablePasteboard)? = nil,
        eventPoster: (any PasteKeyboardEventPosting)? = nil,
        restorationDelay: UInt64 = 150_000_000
    ) {
        self.pasteboard = pasteboard ?? SystemRestorablePasteboard()
        self.eventPoster = eventPoster ?? SystemPasteKeyboardEventPoster()
        self.restorationDelay = restorationDelay
    }

    public func paste(_ text: String) async throws {
        let snapshot = pasteboard.snapshot()
        defer { pasteboard.restore(snapshot) }
        guard pasteboard.writeString(text) else {
            throw RestoringPasteError.couldNotWritePasteboard
        }
        try eventPoster.postPaste()
        if restorationDelay > 0 {
            try await Task.sleep(nanoseconds: restorationDelay)
        }
    }
}

public enum RestoringPasteError: LocalizedError {
    case couldNotWritePasteboard
    case couldNotCreateEvents

    public var errorDescription: String? {
        switch self {
        case .couldNotWritePasteboard:
            return "Could not write the transcript to the clipboard"
        case .couldNotCreateEvents:
            return "Could not create paste keyboard events"
        }
    }
}
