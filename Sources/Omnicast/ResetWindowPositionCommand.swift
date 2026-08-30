// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore

struct ResetWindowPositionProvider: CommandProvider {
    let reset: @MainActor @Sendable () -> Void

    func commands() async -> [any Command] {
        [ResetWindowPositionCommand(reset: reset)]
    }
}

private struct ResetWindowPositionCommand: Command {
    let reset: @MainActor @Sendable () -> Void
    let id = "system:reset-window-position"
    let title = "Reset Window Position"
    let subtitle = "Move the launcher to its default position"
    let icon: CommandIcon = .sfSymbol("rectangle.center.inset.filled")
    let keywords = ["launcher", "panel", "center", "position"]
    let kind: CommandKind = .system

    @MainActor
    func execute(context: CommandContext) async throws {
        reset()
    }
}
