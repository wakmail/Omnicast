// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

@MainActor
public final class EmojiPasteService {
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
        rememberFrontmostApplication()
    }

    public func rememberFrontmostApplication() {
        guard let application = workspace.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        previousApplication = application
    }

    public func paste(_ emoji: String) async throws {
        pasteboard.declareTypes([.string], owner: nil)
        guard pasteboard.setString(emoji, forType: .string) else {
            throw EmojiPasteError.couldNotWritePasteboard
        }
        didWritePasteboard?()
        guard let application = previousApplication, !application.isTerminated else {
            throw EmojiPasteError.noPreviousApplication
        }
        guard application.activate() else {
            throw EmojiPasteError.couldNotActivateApplication
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
            throw EmojiPasteError.couldNotCreateKeyboardEvents
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

public enum EmojiPasteError: LocalizedError {
    case couldNotWritePasteboard
    case noPreviousApplication
    case couldNotActivateApplication
    case couldNotCreateKeyboardEvents

    public var errorDescription: String? {
        switch self {
        case .couldNotWritePasteboard:
            return "Could not write the emoji to the clipboard"
        case .noPreviousApplication:
            return "No previous application is available"
        case .couldNotActivateApplication:
            return "Could not activate the previous application"
        case .couldNotCreateKeyboardEvents:
            return "Could not create paste keyboard events"
        }
    }
}
