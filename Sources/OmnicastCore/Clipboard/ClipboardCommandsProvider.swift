// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct ClipboardHistoryCommand: ViewPresentingCommand {
    public let id = "clipboard:history"
    public let title = "Clipboard History"
    public let subtitle = "Search and paste recent clipboard items"
    public let icon = CommandIcon.sfSymbol("doc.on.clipboard")
    public let keywords = ["clipboard", "copy", "paste", "history"]
    public let kind = CommandKind.clipboard

    public init() {}

    @MainActor
    public func execute(context: CommandContext) async throws {}
}

public struct ClipboardCommandsProvider: CommandProvider {
    public init() {}

    public func commands() async -> [any Command] {
        [ClipboardHistoryCommand()]
    }
}
