// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum CommandIcon: Equatable, Sendable {
    case sfSymbol(String)
    case appBundle(URL)
    case image(URL)
    case emoji(String)
}

public enum CommandKind: String, Codable, Sendable {
    case application = "Application"
    case system = "System"
}

public protocol Command: Sendable {
    var id: String { get }
    var title: String { get }
    var subtitle: String { get }
    var icon: CommandIcon { get }
    var keywords: [String] { get }
    var kind: CommandKind { get }
    var resourceURL: URL? { get }

    @MainActor
    func execute(context: CommandContext) async throws
}

public extension Command {
    var resourceURL: URL? { nil }
}
