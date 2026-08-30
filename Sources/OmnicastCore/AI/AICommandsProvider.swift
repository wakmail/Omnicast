// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum AICommandDestination: Sendable {
    case ask
    case chat
}

public struct AICommandsProvider: CommandProvider {
    private let open: @MainActor @Sendable (AICommandDestination) -> Void

    public init(open: @escaping @MainActor @Sendable (AICommandDestination) -> Void) {
        self.open = open
    }

    public func commands() async -> [any Command] {
        [
            AIEntryCommand(
                id: "ai:ask",
                title: "Ask AI",
                subtitle: "Start a new AI conversation",
                icon: .sfSymbol("sparkles"),
                keywords: ["question", "prompt", "assistant"],
                destination: .ask,
                open: open
            ),
            AIEntryCommand(
                id: "ai:chat",
                title: "AI Chat",
                subtitle: "Open AI conversations",
                icon: .sfSymbol("bubble.left.and.bubble.right.fill"),
                keywords: ["history", "conversation", "assistant"],
                destination: .chat,
                open: open
            )
        ]
    }
}

private struct AIEntryCommand: Command {
    let id: String
    let title: String
    let subtitle: String
    let icon: CommandIcon
    let keywords: [String]
    let kind = CommandKind.ai
    let destination: AICommandDestination
    let open: @MainActor @Sendable (AICommandDestination) -> Void

    @MainActor
    func execute(context: CommandContext) async throws {
        open(destination)
    }
}
