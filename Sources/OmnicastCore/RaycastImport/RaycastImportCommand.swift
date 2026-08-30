// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct ImportFromRaycastCommand: ViewPresentingCommand {
    public let id = "raycast.import"
    public let title = "Import from Raycast"
    public let subtitle = "Restore a Raycast backup"
    public let icon = CommandIcon.sfSymbol("square.and.arrow.down")
    public let keywords = ["raycast", "backup", "settings", "restore"]
    public let kind = CommandKind.system

    public init() {}

    @MainActor
    public func execute(context: CommandContext) async throws {}
}

public struct RaycastImportCommandProvider: CommandProvider {
    public init() {}

    public func commands() async -> [any Command] {
        [ImportFromRaycastCommand()]
    }
}
