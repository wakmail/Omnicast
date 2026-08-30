// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore

@MainActor
public struct ExtensionHostCallbacks {
    public var showToast: (String) -> Void
    public var showHUD: (String) -> Void
    public var closeMainWindow: () -> Void

    public init(
        showToast: @escaping (String) -> Void = { _ in },
        showHUD: @escaping (String) -> Void = { _ in },
        closeMainWindow: @escaping () -> Void = {}
    ) {
        self.showToast = showToast
        self.showHUD = showHUD
        self.closeMainWindow = closeMainWindow
    }
}

public enum ExtensionBridgeError: LocalizedError {
    case missingPayloadValue(String)
    case invalidURL(String)

    public var errorDescription: String? {
        switch self {
        case .missingPayloadValue(let name):
            "The bridge message is missing \(name)"
        case .invalidURL(let value):
            "The bridge message contains an invalid URL: \(value)"
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

    public init(
        extensionSlug: String,
        persistence: ExtensionPersistence,
        clipboard: any ClipboardService,
        opener: any OpenerService,
        callbacks: ExtensionHostCallbacks
    ) {
        self.extensionSlug = extensionSlug
        self.persistence = persistence
        self.clipboard = clipboard
        self.opener = opener
        self.callbacks = callbacks
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
        }
    }

    private func string(_ key: String, in payload: [String: JSONValue]) throws -> String {
        guard case .string(let value) = payload[key] else {
            throw ExtensionBridgeError.missingPayloadValue(key)
        }
        return value
    }
}
