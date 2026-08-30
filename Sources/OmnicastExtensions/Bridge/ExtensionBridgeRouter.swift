// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore

@MainActor
public struct ExtensionHostCallbacks {
    public var showToast: (String) -> Void
    public var showHUD: (String) -> Void
    public var closeMainWindow: () -> Void
    public var extensionRegistryChanged: () -> Void

    public init(
        showToast: @escaping (String) -> Void = { _ in },
        showHUD: @escaping (String) -> Void = { _ in },
        closeMainWindow: @escaping () -> Void = {},
        extensionRegistryChanged: @escaping () -> Void = {}
    ) {
        self.showToast = showToast
        self.showHUD = showHUD
        self.closeMainWindow = closeMainWindow
        self.extensionRegistryChanged = extensionRegistryChanged
    }
}

public enum ExtensionBridgeError: LocalizedError {
    case missingPayloadValue(String)
    case invalidURL(String)
    case storeAccessDenied
    case storeServicesUnavailable

    public var errorDescription: String? {
        switch self {
        case .missingPayloadValue(let name):
            "The bridge message is missing \(name)"
        case .invalidURL(let value):
            "The bridge message contains an invalid URL: \(value)"
        case .storeAccessDenied:
            "The Store bridge is available only to the builtin Store extension"
        case .storeServicesUnavailable:
            "The Store bridge services are unavailable"
        }
    }
}

@MainActor
public final class ExtensionBridgeRouter {
    public let extensionSlug: String

    private let persistence: ExtensionPersistence
    private let clipboard: any ClipboardService
    private let opener: any OpenerService
    private let callbacks: ExtensionHostCallbacks
    private let storeCatalog: RaycastStoreCatalog?
    private let extensionRegistry: ExtensionRegistry?
    private let nodeBridge = ExtensionNodeBridge()

    public init(
        extensionSlug: String,
        persistence: ExtensionPersistence,
        clipboard: any ClipboardService,
        opener: any OpenerService,
        callbacks: ExtensionHostCallbacks,
        storeCatalog: RaycastStoreCatalog? = nil,
        extensionRegistry: ExtensionRegistry? = nil
    ) {
        self.extensionSlug = extensionSlug
        self.persistence = persistence
        self.clipboard = clipboard
        self.opener = opener
        self.callbacks = callbacks
        self.storeCatalog = storeCatalog
        self.extensionRegistry = extensionRegistry
    }

    public func route(_ request: ExtensionBridgeRequest) async -> ExtensionBridgeResponse {
        do {
            return try await perform(request)
        } catch {
            return .failure(
                id: request.id,
                error: error.localizedDescription
            )
        }
    }

    private func perform(_ request: ExtensionBridgeRequest) async throws -> ExtensionBridgeResponse {
        switch request.operation {
        case .localStorageGetItem:
            let key = try string("key", in: request.payload)
            let values = try await persistence.localStorage(extensionSlug: extensionSlug)
            return .success(id: request.id, result: values[key] ?? .null)
        case .localStorageSetItem:
            let key = try string("key", in: request.payload)
            guard let value = request.payload["value"] else {
                throw ExtensionBridgeError.missingPayloadValue("value")
            }
            try await persistence.setLocalStorageValue(
                value,
                forKey: key,
                extensionSlug: extensionSlug
            )
            return .success(id: request.id)
        case .localStorageRemoveItem:
            let key = try string("key", in: request.payload)
            try await persistence.removeLocalStorageValue(
                forKey: key,
                extensionSlug: extensionSlug
            )
            return .success(id: request.id)
        case .localStorageAllItems:
            let values = try await persistence.localStorage(extensionSlug: extensionSlug)
            return .success(id: request.id, result: .object(values))
        case .localStorageClear:
            try await persistence.clearLocalStorage(extensionSlug: extensionSlug)
            return .success(id: request.id)
        case .preferencesGet:
            let values = try await persistence.preferences(extensionSlug: extensionSlug)
            return .success(id: request.id, result: .object(values))
        case .preferencesSet:
            guard case .object(let values) = request.payload["values"] else {
                throw ExtensionBridgeError.missingPayloadValue("values")
            }
            try await persistence.setPreferences(values, extensionSlug: extensionSlug)
            return .success(id: request.id)
        case .clipboardReadText:
            if let text = clipboard.readText() {
                return .success(id: request.id, result: .string(text))
            }
            return .success(id: request.id)
        case .clipboardWriteText:
            clipboard.writeText(try string("text", in: request.payload))
            return .success(id: request.id)
        case .open:
            let rawURL = try string("url", in: request.payload)
            guard let url = URL(string: rawURL) else {
                throw ExtensionBridgeError.invalidURL(rawURL)
            }
            try await opener.open(url)
            return .success(id: request.id)
        case .toast:
            callbacks.showToast(try string("message", in: request.payload))
            return .success(id: request.id)
        case .hud:
            callbacks.showHUD(try string("message", in: request.payload))
            return .success(id: request.id)
        case .closeMainWindow:
            callbacks.closeMainWindow()
            return .success(id: request.id)
        case .childProcessExec:
            return .success(
                id: request.id,
                result: try await nodeBridge.executeProcess(payload: request.payload)
            )
        case .fileSystemAccess:
            return .success(id: request.id, result: try nodeBridge.access(payload: request.payload))
        case .fileSystemReadFile:
            return .success(id: request.id, result: try nodeBridge.readFile(payload: request.payload))
        case .fileSystemStat:
            return .success(id: request.id, result: try nodeBridge.stat(payload: request.payload))
        case .fileSystemReadDirectory:
            return .success(
                id: request.id,
                result: try nodeBridge.readDirectory(payload: request.payload)
            )
        case .fileSystemWriteFile:
            return .success(id: request.id, result: try nodeBridge.writeFile(payload: request.payload))
        case .fileSystemMakeDirectory:
            return .success(
                id: request.id,
                result: try nodeBridge.makeDirectory(payload: request.payload)
            )
        case .fetch:
            return .success(
                id: request.id,
                result: try await nodeBridge.fetch(payload: request.payload)
            )
        case .storeCatalog:
            let (catalog, _) = try storeServices()
            let extensions = try await catalog.extensions()
            return .success(
                id: request.id,
                result: .array(extensions.map(storeExtensionValue))
            )
        case .storeInstall:
            let (_, registry) = try storeServices()
            let installed = try await registry.install(
                name: try string("name", in: request.payload)
            )
            callbacks.extensionRegistryChanged()
            return .success(
                id: request.id,
                result: .object([
                    "name": .string(installed.slug),
                    "title": .string(installed.manifest.title)
                ])
            )
        case .storeInstalled:
            let (_, registry) = try storeServices()
            let installed = try await registry.listInstalled()
            return .success(
                id: request.id,
                result: .array(installed.map { .string($0.slug) })
            )
        }
    }

    private func storeServices() throws -> (RaycastStoreCatalog, ExtensionRegistry) {
        guard extensionSlug == ExtensionRegistry.builtinStoreSlug else {
            throw ExtensionBridgeError.storeAccessDenied
        }
        guard let storeCatalog, let extensionRegistry else {
            throw ExtensionBridgeError.storeServicesUnavailable
        }
        return (storeCatalog, extensionRegistry)
    }

    private func storeExtensionValue(_ value: RaycastStoreExtension) -> JSONValue {
        .object([
            "name": .string(value.name),
            "title": .string(value.title),
            "description": .string(value.description),
            "author": .string(value.author),
            "iconURL": value.iconURL.map { .string($0.absoluteString) } ?? .null,
            "screenshots": .array(value.screenshotURLs.map {
                .string($0.absoluteString)
            }),
            "categories": .array(value.categories.map(JSONValue.string)),
            "platforms": .array(value.platforms.map(JSONValue.string)),
            "commands": .array(value.commands.map { command in
                .object([
                    "name": .string(command.name),
                    "title": .string(command.title),
                    "description": .string(command.description)
                ])
            }),
            "installCount": .number(Double(value.installCount))
        ])
    }

    private func string(_ key: String, in payload: [String: JSONValue]) throws -> String {
        guard case .string(let value) = payload[key] else {
            throw ExtensionBridgeError.missingPayloadValue(key)
        }
        return value
    }
}
