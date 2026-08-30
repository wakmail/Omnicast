// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public protocol ArgumentTakingCommand: Command {
    var requiresArgument: Bool { get }
    var argumentPlaceholder: String { get }

    @MainActor
    func execute(argument: String, context: CommandContext) async throws
}

@MainActor
public protocol ApplicationBundleOpener: OpenerService {
    func open(_ url: URL, withApplicationBundleIdentifier bundleIdentifier: String) async throws
}

public struct QuicklinkCommand: ArgumentTakingCommand {
    public let quicklink: Quicklink

    public var id: String { "quicklink-\(quicklink.id.uuidString.lowercased())" }
    public var title: String { quicklink.name }
    public var subtitle: String { quicklink.openWithAppBundleIdentifier ?? "Quick Link" }
    public var icon: CommandIcon { Self.commandIcon(quicklink.icon) }
    public var keywords: [String] {
        [quicklink.name, quicklink.urlTemplate, quicklink.openWithAppBundleIdentifier ?? ""]
    }
    public let kind: CommandKind = .quicklink
    public var resourceURL: URL? { try? quicklink.resolvedURL() }
    public var requiresArgument: Bool { quicklink.requiresArgument }
    public var argumentPlaceholder: String { "Search query" }

    public init(quicklink: Quicklink) {
        self.quicklink = quicklink
    }

    @MainActor
    public func execute(context: CommandContext) async throws {
        if requiresArgument {
            throw QuicklinkError.missingQuery
        }
        try await open(quicklink.resolvedURL(), context: context)
    }

    @MainActor
    public func execute(argument: String, context: CommandContext) async throws {
        try await open(quicklink.resolvedURL(query: argument), context: context)
    }

    @MainActor
    private func open(_ url: URL, context: CommandContext) async throws {
        if let bundleIdentifier = quicklink.openWithAppBundleIdentifier,
           let opener = context.opener as? any ApplicationBundleOpener {
            try await opener.open(url, withApplicationBundleIdentifier: bundleIdentifier)
        } else {
            try await context.opener.open(url)
        }
    }

    private static func commandIcon(_ value: String) -> CommandIcon {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalized.lowercased() {
        case "search": return .sfSymbol("magnifyingglass")
        case "globe": return .sfSymbol("globe")
        case "link", "default": return .sfSymbol("link")
        case "bolt": return .sfSymbol("bolt")
        default:
            if let url = URL(string: normalized), url.scheme != nil {
                return .image(url)
            }
            if normalized.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) {
                return .emoji(normalized)
            }
            return .sfSymbol("link")
        }
    }
}

public struct QuicklinkCommandsProvider: CommandProvider {
    public let directoryURL: URL

    public init(directoryURL: URL = OmnicastDataDirectory.defaultURL) {
        self.directoryURL = directoryURL
    }

    public func commands() async -> [any Command] {
        let directoryURL = directoryURL
        let quicklinks: [Quicklink]
        do {
            quicklinks = try await MainActor.run {
                try QuicklinkStore(directoryURL: directoryURL).quicklinks
            }
        } catch {
            return []
        }
        return quicklinks.map { QuicklinkCommand(quicklink: $0) as any Command }
    }
}
