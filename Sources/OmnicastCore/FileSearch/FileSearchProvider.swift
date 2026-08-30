// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct FileSearchCommand: Command {
    public let id = "file-search"
    public let title = "Search Files"
    public let subtitle = "Find files and folders"
    public let icon: CommandIcon = .sfSymbol("doc.text.magnifyingglass")
    public let keywords = ["file", "folder", "document", "spotlight", "find"]
    public let kind: CommandKind = .file
    public let resourceURL = URL(string: "omnicast://file-search")

    public init() {}

    @MainActor
    public func execute(context: CommandContext) async throws {
        guard let resourceURL else { return }
        try await context.opener.open(resourceURL)
    }
}

public struct FileSearchProvider: CommandProvider {
    public init() {}

    public func commands() async -> [any Command] {
        [FileSearchCommand()]
    }
}
