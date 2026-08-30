// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct SearchMenuItemsCommand: ViewPresentingCommand {
    public let id = "menu:search"
    public let title = "Search Menu Items"
    public let subtitle = "Run a command from the current application menu"
    public let icon = CommandIcon.sfSymbol("menubar.rectangle")
    public let keywords = ["menu", "command", "shortcut", "application"]
    public let kind = CommandKind.system

    public init() {}

    @MainActor
    public func execute(context: CommandContext) async throws {}
}

public struct MenuSearchCommandsProvider: CommandProvider {
    public init() {}

    public func commands() async -> [any Command] {
        [SearchMenuItemsCommand()]
    }
}
