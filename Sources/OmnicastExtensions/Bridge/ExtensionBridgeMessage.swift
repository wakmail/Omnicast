// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum ExtensionBridgeOperation: String, Codable, Sendable {
    case localStorageGetItem
    case localStorageSetItem
    case localStorageRemoveItem
    case localStorageAllItems
    case localStorageClear
    case preferencesGet
    case preferencesSet
    case clipboardReadText
    case clipboardWriteText
    case open
    case toast
    case hud
    case closeMainWindow
    case childProcessExec
    case fileSystemAccess
    case fileSystemReadFile
    case fileSystemStat
    case fileSystemReadDirectory
    case fileSystemWriteFile
    case fileSystemMakeDirectory
    case fetch
}

public struct ExtensionBridgeRequest: Codable, Equatable, Sendable {
    public let id: String
    public let operation: ExtensionBridgeOperation
    public let payload: [String: JSONValue]

    public init(
        id: String,
        operation: ExtensionBridgeOperation,
        payload: [String: JSONValue] = [:]
    ) {
        self.id = id
        self.operation = operation
        self.payload = payload
    }
}

public struct ExtensionBridgeResponse: Codable, Equatable, Sendable {
    public let id: String
    public let result: JSONValue?
    public let error: String?

    public init(id: String, result: JSONValue? = nil, error: String? = nil) {
        self.id = id
        self.result = result
        self.error = error
    }

    public static func success(id: String, result: JSONValue = .null) -> Self {
        ExtensionBridgeResponse(id: id, result: result)
    }

    public static func failure(id: String, error: String) -> Self {
        ExtensionBridgeResponse(id: id, error: error)
    }
}
