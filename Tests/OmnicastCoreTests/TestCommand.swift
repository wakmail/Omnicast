// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore

struct TestCommand: Command {
    let id: String
    let title: String
    let subtitle: String
    let icon: CommandIcon = .sfSymbol("circle")
    let keywords: [String]
    let kind: CommandKind

    init(
        id: String,
        title: String,
        subtitle: String = "",
        keywords: [String] = [],
        kind: CommandKind = .application
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.kind = kind
    }

    @MainActor
    func execute(context: CommandContext) async throws {}
}

func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
