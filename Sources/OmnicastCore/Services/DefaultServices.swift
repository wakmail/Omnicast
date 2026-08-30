// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation

@MainActor
public final class SystemClipboardService: ClipboardService {
    public init() {}

    public func readText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    public func writeText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

@MainActor
public final class WorkspaceOpenerService: OpenerService {
    public init() {}

    public func open(_ url: URL) async throws {
        if url.isFileURL, url.pathExtension.lowercased() == "app" {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } else if !NSWorkspace.shared.open(url) {
            throw OpenerError.couldNotOpen(url)
        }
    }

    public func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

public enum OpenerError: LocalizedError {
    case couldNotOpen(URL)

    public var errorDescription: String? {
        switch self {
        case .couldNotOpen(let url):
            return "Could not open \(url.lastPathComponent)"
        }
    }
}
