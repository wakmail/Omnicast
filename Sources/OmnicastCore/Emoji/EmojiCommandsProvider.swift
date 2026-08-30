// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct SearchEmojiCommand: ViewPresentingCommand {
    public let id = "emoji:search"
    public let title = "Search Emoji"
    public let subtitle = "Find and paste an emoji"
    public let icon = CommandIcon.emoji("😀")
    public let keywords = ["emoji", "emoticon", "smiley", "symbol"]
    public let kind = CommandKind.system

    public init() {}

    @MainActor
    public func execute(context: CommandContext) async throws {}
}

public struct EmojiCommandsProvider: CommandProvider {
    public init() {}

    public func commands() async -> [any Command] {
        [SearchEmojiCommand()]
    }
}
