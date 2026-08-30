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
    case clipboard = "Clipboard"
    case snippet = "Snippet"
    case quicklink = "Quick Link"
    case script = "Script"
    case file = "File"
    case window = "Window"
    case ai = "AI"
    case extensionCommand = "Extension"
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

public protocol ViewPresentingCommand: Command {
    var presentationID: String { get }
}

public extension ViewPresentingCommand {
    var presentationID: String { id }
}

public extension Command {
    var resourceURL: URL? { nil }
}
