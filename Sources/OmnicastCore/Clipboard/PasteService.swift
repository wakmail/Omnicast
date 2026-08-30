// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

@MainActor
public final class PasteService {
    public var didWritePasteboard: (() -> Void)?

    private let pasteboard: NSPasteboard
    private let workspace: NSWorkspace
    private var previousApplication: NSRunningApplication?

    public init(
        pasteboard: NSPasteboard = .general,
        workspace: NSWorkspace = .shared
    ) {
        self.pasteboard = pasteboard
        self.workspace = workspace
        previousApplication = workspace.frontmostApplication
    }

    public var previousApplicationName: String? {
        previousApplication?.localizedName
    }

    public func rememberFrontmostApplication() {
        guard let application = workspace.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        previousApplication = application
    }

    public func copyOnly(_ item: ClipboardItem) throws {
        switch item.kind {
        case .text:
            guard let text = item.textContent else {
                throw PasteServiceError.missingText
            }
            pasteboard.declareTypes([.string], owner: nil)
            guard pasteboard.setString(text, forType: .string) else {
                throw PasteServiceError.couldNotWritePasteboard
            }
        case .image:
            guard let imageURL = item.imageURL,
                  let pngData = try? Data(contentsOf: imageURL),
                  let image = NSImage(data: pngData) else {
                throw PasteServiceError.missingImage
            }
            var types = [NSPasteboard.PasteboardType.png]
            if image.tiffRepresentation != nil {
                types.append(.tiff)
            }
            pasteboard.declareTypes(types, owner: nil)
            let wrotePNG = pasteboard.setData(pngData, forType: .png)
            let wroteTIFF = image.tiffRepresentation.map {
                pasteboard.setData($0, forType: .tiff)
            } ?? false
            guard wrotePNG || wroteTIFF else {
                throw PasteServiceError.couldNotWritePasteboard
            }
        case .files:
            let fileObjects = item.fileURLs.map { $0 as NSURL }
            pasteboard.clearContents()
            guard !fileObjects.isEmpty,
                  pasteboard.writeObjects(fileObjects) else {
                throw PasteServiceError.missingFiles
            }
        }

        didWritePasteboard?()
    }

    public func paste(_ item: ClipboardItem) async throws {
        try copyOnly(item)
        guard let application = previousApplication,
              !application.isTerminated else {
            throw PasteServiceError.noPreviousApplication
        }
        guard application.activate() else {
            throw PasteServiceError.couldNotActivateApplication
        }

        await waitUntilFrontmost(application)
        try postPasteEvents()
    }

    private func waitUntilFrontmost(_ application: NSRunningApplication) async {
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(500))
        while ContinuousClock.now < deadline {
            if workspace.frontmostApplication?.processIdentifier == application.processIdentifier {
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    private func postPasteEvents() throws {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
              ) else {
            throw PasteServiceError.couldNotCreateKeyboardEvents
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

public enum PasteServiceError: LocalizedError {
    case missingText
    case missingImage
    case missingFiles
    case couldNotWritePasteboard
    case noPreviousApplication
    case couldNotActivateApplication
    case couldNotCreateKeyboardEvents

    public var errorDescription: String? {
        switch self {
        case .missingText:
            return "The clipboard item has no text"
        case .missingImage:
            return "The clipboard image file is unavailable"
        case .missingFiles:
            return "The clipboard item has no files"
        case .couldNotWritePasteboard:
            return "Could not write to the clipboard"
        case .noPreviousApplication:
            return "No previous application is available"
        case .couldNotActivateApplication:
            return "Could not activate the previous application"
        case .couldNotCreateKeyboardEvents:
            return "Could not create paste keyboard events"
        }
    }
}
