// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore

public struct InstalledExtensionCommand: Equatable, Sendable {
    public let extensionSlug: String
    public let manifest: ExtensionCommandManifest
    public let extensionDirectoryURL: URL
    public let bundleURL: URL

    public init(
        extensionSlug: String,
        manifest: ExtensionCommandManifest,
        extensionDirectoryURL: URL,
        bundleURL: URL
    ) {
        self.extensionSlug = extensionSlug
        self.manifest = manifest
        self.extensionDirectoryURL = extensionDirectoryURL
        self.bundleURL = bundleURL
    }
}

public struct InstalledExtension: Equatable, Sendable {
    public let slug: String
    public let directoryURL: URL
    public let manifest: ExtensionManifest
    public let isBuiltin: Bool

    public init(
        slug: String,
        directoryURL: URL,
        manifest: ExtensionManifest,
        isBuiltin: Bool = false
    ) {
        self.slug = slug
        self.directoryURL = directoryURL
        self.manifest = manifest
        self.isBuiltin = isBuiltin
    }

    public var commands: [InstalledExtensionCommand] {
        manifest.commands.map { command in
            let bundleURL: URL
            if isBuiltin {
                bundleURL = directoryURL.appendingPathComponent(
                    command.source ?? "\(command.name).js"
                )
            } else {
                bundleURL = directoryURL
                    .appendingPathComponent(".sc-build", isDirectory: true)
                    .appendingPathComponent("\(command.name).js")
            }
            return InstalledExtensionCommand(
                extensionSlug: slug,
                manifest: command,
                extensionDirectoryURL: directoryURL,
                bundleURL: bundleURL
            )
        }
    }
}

public enum ExtensionRegistryError: LocalizedError {
    case invalidSlug(String)
    case missingManifest
    case missingBuildDirectory
    case missingCommandBundle(String)
    case noCommands
    case couldNotLocateExtractedExtension
    case missingBuiltinStore
    case builtinExtensionCannotBeModified(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSlug(let slug):
            "Invalid extension store slug: \(slug)"
        case .missingManifest:
            "The extension bundle does not contain package.json"
        case .missingBuildDirectory:
            "The extension bundle does not contain prepared command output"
        case .missingCommandBundle(let name):
            "The extension bundle does not contain command output for \(name)"
        case .noCommands:
            "The extension manifest does not declare any commands"
        case .couldNotLocateExtractedExtension:
            "The extracted extension directory could not be located"
        case .missingBuiltinStore:
            "The builtin Store extension bundle is missing"
        case .builtinExtensionCannotBeModified(let slug):
            "The builtin extension cannot be modified: \(slug)"
        }
    }
}

public actor ExtensionRegistry {
    public static let builtinStoreSlug = "store"
    public static let builtinStoreCommandName = "index"

    public let extensionsDirectoryURL: URL

    private let store: any RaycastStoreServing
    private let fileManager: FileManager

    public init(
        directoryURL: URL = OmnicastDataDirectory.defaultURL,
        store: any RaycastStoreServing = RaycastStoreClient(),
        fileManager: FileManager = .default
    ) {
        extensionsDirectoryURL = directoryURL.appendingPathComponent(
            "extensions",
            isDirectory: true
        )
        self.store = store
        self.fileManager = fileManager
    }

    public func listInstalled() throws -> [InstalledExtension] {
        let builtin = try builtinStoreExtension()
        guard fileManager.fileExists(atPath: extensionsDirectoryURL.path) else {
            return [builtin]
        }
        let urls = try fileManager.contentsOfDirectory(
            at: extensionsDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let installed: [InstalledExtension] = try urls.compactMap { directoryURL in
            guard directoryURL.lastPathComponent != Self.builtinStoreSlug else {
                return nil
            }
            let values = try directoryURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { return nil }
            let manifestURL = directoryURL.appendingPathComponent("package.json")
            guard fileManager.fileExists(atPath: manifestURL.path) else { return nil }
            let manifest = try ExtensionManifest.decode(from: Data(contentsOf: manifestURL))
            return InstalledExtension(
                slug: directoryURL.lastPathComponent,
                directoryURL: directoryURL,
                manifest: manifest
            )
        }
        return ([builtin] + installed).sorted {
            $0.manifest.title.localizedCaseInsensitiveCompare($1.manifest.title) == .orderedAscending
        }
    }

    public func installedExtension(slug: String) throws -> InstalledExtension? {
        try validate(slug: slug)
        if slug == Self.builtinStoreSlug {
            return try builtinStoreExtension()
        }
        let directoryURL = extensionsDirectoryURL.appendingPathComponent(slug, isDirectory: true)
        let manifestURL = directoryURL.appendingPathComponent("package.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else { return nil }
        let manifest = try ExtensionManifest.decode(from: Data(contentsOf: manifestURL))
        return InstalledExtension(slug: slug, directoryURL: directoryURL, manifest: manifest)
    }

    public func install(name: String) async throws -> InstalledExtension {
        try validate(slug: name)
        guard name != Self.builtinStoreSlug else {
            throw ExtensionRegistryError.builtinExtensionCannotBeModified(name)
        }
        let bundle = try await store.downloadBundle(for: name)
        guard bundle.type == "bundle" else {
            throw RaycastStoreError.sourceArchiveUnsupported
        }
        try fileManager.createDirectory(
            at: extensionsDirectoryURL,
            withIntermediateDirectories: true
        )
        let archiveURL = extensionsDirectoryURL.appendingPathComponent(
            ".download.\(UUID().uuidString).tar.gz"
        )
        defer { try? fileManager.removeItem(at: archiveURL) }
        try bundle.data.write(to: archiveURL, options: .atomic)
        return try installArchive(at: archiveURL, preferredSlug: name)
    }

    public func install(storeSlug slug: String) async throws -> InstalledExtension {
        try await install(name: slug)
    }

    public func install(fromArchive archiveURL: URL) throws -> InstalledExtension {
        try fileManager.createDirectory(
            at: extensionsDirectoryURL,
            withIntermediateDirectories: true
        )
        return try installArchive(at: archiveURL, preferredSlug: nil)
    }

    private func installArchive(
        at archiveURL: URL,
        preferredSlug: String?
    ) throws -> InstalledExtension {
        if let preferredSlug {
            try validate(slug: preferredSlug)
        }

        let transactionURL = extensionsDirectoryURL.appendingPathComponent(
            ".install.\(UUID().uuidString)",
            isDirectory: true
        )
        let extractedURL = transactionURL.appendingPathComponent("contents", isDirectory: true)
        try fileManager.createDirectory(at: transactionURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: transactionURL) }

        try TarGzipExtractor.extract(archiveURL: archiveURL, destinationURL: extractedURL)
        let sourceURL = try locateExtension(in: extractedURL, preferredSlug: preferredSlug ?? "")
        let manifest = try validateBundle(at: sourceURL)
        let slug = preferredSlug ?? manifest.name
        try validate(slug: slug)

        let destinationURL = extensionsDirectoryURL.appendingPathComponent(slug, isDirectory: true)
        let backupURL = extensionsDirectoryURL.appendingPathComponent(
            ".backup.\(slug).\(UUID().uuidString)",
            isDirectory: true
        )
        let hadExisting = fileManager.fileExists(atPath: destinationURL.path)
        if hadExisting {
            try fileManager.moveItem(at: destinationURL, to: backupURL)
        }

        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            if hadExisting {
                try fileManager.removeItem(at: backupURL)
            }
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            if hadExisting, fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.moveItem(at: backupURL, to: destinationURL)
            }
            throw error
        }

        return InstalledExtension(slug: slug, directoryURL: destinationURL, manifest: manifest)
    }

    public func uninstall(slug: String) throws {
        try validate(slug: slug)
        guard slug != Self.builtinStoreSlug else {
            throw ExtensionRegistryError.builtinExtensionCannotBeModified(slug)
        }
        let directoryURL = extensionsDirectoryURL.appendingPathComponent(slug, isDirectory: true)
        if fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.removeItem(at: directoryURL)
        }
    }

    private func validate(slug: String) throws {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        if slug.isEmpty || slug.rangeOfCharacter(from: allowed.inverted) != nil {
            throw ExtensionRegistryError.invalidSlug(slug)
        }
    }

    private func builtinStoreExtension() throws -> InstalledExtension {
        guard let manifestURL = Bundle.module.url(
            forResource: "package",
            withExtension: "json",
            subdirectory: "builtin/store"
        ) else {
            throw ExtensionRegistryError.missingBuiltinStore
        }
        let directoryURL = manifestURL.deletingLastPathComponent()
        let manifest = try ExtensionManifest.decode(from: Data(contentsOf: manifestURL))
        guard manifest.name == Self.builtinStoreSlug,
              manifest.commands.contains(where: {
                  $0.name == Self.builtinStoreCommandName
              }) else {
            throw ExtensionRegistryError.missingBuiltinStore
        }
        let installed = InstalledExtension(
            slug: Self.builtinStoreSlug,
            directoryURL: directoryURL,
            manifest: manifest,
            isBuiltin: true
        )
        guard installed.commands.allSatisfy({
            fileManager.fileExists(atPath: $0.bundleURL.path)
        }) else {
            throw ExtensionRegistryError.missingBuiltinStore
        }
        return installed
    }

    private func locateExtension(in rootURL: URL, preferredSlug: String) throws -> URL {
        if fileManager.fileExists(
            atPath: rootURL.appendingPathComponent("package.json").path
        ) {
            return rootURL
        }
        let preferredURL = rootURL.appendingPathComponent(preferredSlug, isDirectory: true)
        if fileManager.fileExists(
            atPath: preferredURL.appendingPathComponent("package.json").path
        ) {
            return preferredURL
        }
        let children = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        if let directory = children.first(where: {
            fileManager.fileExists(atPath: $0.appendingPathComponent("package.json").path)
        }) {
            return directory
        }
        throw ExtensionRegistryError.couldNotLocateExtractedExtension
    }

    private func validateBundle(at directoryURL: URL) throws -> ExtensionManifest {
        let manifestURL = directoryURL.appendingPathComponent("package.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ExtensionRegistryError.missingManifest
        }
        let manifest = try ExtensionManifest.decode(from: Data(contentsOf: manifestURL))
        guard !manifest.commands.isEmpty else {
            throw ExtensionRegistryError.noCommands
        }
        let buildURL = directoryURL.appendingPathComponent(".sc-build", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: buildURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ExtensionRegistryError.missingBuildDirectory
        }
        for command in manifest.commands {
            let bundleURL = buildURL.appendingPathComponent("\(command.name).js")
            guard fileManager.fileExists(atPath: bundleURL.path) else {
                throw ExtensionRegistryError.missingCommandBundle(command.name)
            }
        }
        return manifest
    }
}
