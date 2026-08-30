// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct MyScheduleCommand: Command {
    public let id = "calendar.schedule"
    public let title = "My Schedule"
    public let subtitle = "View today and the coming week"
    public let icon = CommandIcon.sfSymbol("calendar")
    public let keywords = ["calendar", "events", "schedule", "today", "week"]
    public let kind = CommandKind.system

    public init() {}

    @MainActor
    public func execute(context: CommandContext) async throws {}
}

public struct CalendarCommandsProvider: CommandProvider {
    public init() {}

    public func commands() async -> [any Command] {
        [MyScheduleCommand()]
    }
}
