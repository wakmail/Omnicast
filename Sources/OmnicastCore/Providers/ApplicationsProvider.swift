// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct ApplicationCommand: Command {
    public let id: String
    public let title: String
    public let subtitle: String
    public let icon: CommandIcon
    public let keywords: [String]
    public let kind: CommandKind = .application
    public let resourceURL: URL?

    public init(url: URL, title: String, bundleIdentifier: String?) {
        id = bundleIdentifier.map { "application:\($0)" } ?? "application:\(url.path)"
        self.title = title
        subtitle = url.deletingLastPathComponent().path
        icon = .appBundle(url)
        keywords = [title, bundleIdentifier ?? "", url.lastPathComponent]
        resourceURL = url
    }

    @MainActor
    public func execute(context: CommandContext) async throws {
        guard let resourceURL else { return }
        try await context.opener.open(resourceURL)
    }
}

public struct ApplicationsProvider: CommandProvider {
    public let searchDirectories: [URL]

    public init(
        searchDirectories: [URL] = ApplicationsProvider.defaultSearchDirectories
    ) {
        self.searchDirectories = searchDirectories
    }

    public func commands() async -> [any Command] {
        Self.scan(searchDirectories: searchDirectories)
    }

    private static func scan(searchDirectories: [URL]) -> [any Command] {
        let fileManager = FileManager.default
        var seenURLs = Set<URL>()
        var applications: [ApplicationCommand] = []

        for directory in searchDirectories {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                enumerator.skipDescendants()
                let canonicalURL = url.standardizedFileURL
                guard seenURLs.insert(canonicalURL).inserted else { continue }

                let bundle = Bundle(url: canonicalURL)
                let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? canonicalURL.deletingPathExtension().lastPathComponent
                applications.append(
                    ApplicationCommand(
                        url: canonicalURL,
                        title: displayName,
                        bundleIdentifier: bundle?.bundleIdentifier
                    )
                )
            }
        }

        return applications.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    public static var defaultSearchDirectories: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices", isDirectory: true)
        ]
    }
}
