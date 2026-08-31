// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import OmnicastExtensions

struct ExtensionCommandsProvider: CommandProvider {
    let registry: ExtensionRegistry
    let open: @MainActor @Sendable (InstalledExtension, ExtensionCommandManifest) -> Void

    func commands() async -> [any Command] {
        guard let installed = try? await registry.listInstalled() else { return [] }
        return installed.flatMap { extensionValue in
            extensionValue.manifest.commands
                .map { manifest in
                    InstalledExtensionLauncherCommand(
                        installedExtension: extensionValue,
                        manifest: manifest,
                        open: open
                    ) as any Command
                }
        }
    }
}

private struct InstalledExtensionLauncherCommand: Command {
    let installedExtension: InstalledExtension
    let manifest: ExtensionCommandManifest
    let open: @MainActor @Sendable (InstalledExtension, ExtensionCommandManifest) -> Void

    var id: String {
        if installedExtension.isBuiltin,
           installedExtension.slug == ExtensionRegistry.builtinStoreSlug,
           manifest.name == ExtensionRegistry.builtinStoreCommandName {
            return "extension:store"
        }
        return "extension:\(installedExtension.slug):\(manifest.name)"
    }
    var title: String { manifest.title }
    var subtitle: String { installedExtension.manifest.title }
    var icon: CommandIcon {
        let value = manifest.icon ?? installedExtension.manifest.icon
        guard let value, !value.isEmpty else {
            return .sfSymbol("puzzlepiece.extension")
        }
        if let url = URL(string: value), url.scheme != nil {
            return .image(url)
        }
        let directURL = installedExtension.directoryURL.appendingPathComponent(value)
        if FileManager.default.fileExists(atPath: directURL.path) {
            return .image(directURL)
        }
        let assetURL = installedExtension.directoryURL
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent(value)
        return FileManager.default.fileExists(atPath: assetURL.path)
            ? .image(assetURL)
            : .sfSymbol("puzzlepiece.extension")
    }
    var keywords: [String] {
        [
            installedExtension.slug,
            installedExtension.manifest.title,
            manifest.description
        ]
    }
    let kind: CommandKind = .extensionCommand

    @MainActor
    func execute(context: CommandContext) async throws {
        open(installedExtension, manifest)
    }
}
