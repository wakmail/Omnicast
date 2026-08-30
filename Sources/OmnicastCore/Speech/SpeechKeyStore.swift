// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Security

public protocol SpeechKeyStoring: Sendable {
    func elevenLabsAPIKey() throws -> String?
    func setElevenLabsAPIKey(_ key: String) throws
    func deleteElevenLabsAPIKey() throws
}

public final class SpeechKeyStore: SpeechKeyStoring, @unchecked Sendable {
    public static let service = "com.omnicast.ai"
    public static let account = "elevenlabs"

    public init() {}

    public func elevenLabsAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SpeechKeyStoreError.status(status) }
        guard let data = result as? Data else { return nil }
        let key = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    public func setElevenLabsAPIKey(_ key: String) throws {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            try deleteElevenLabsAPIKey()
            return
        }
        let query = baseQuery()
        let update = [kSecValueData as String: Data(key.utf8)]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(key.utf8)
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SpeechKeyStoreError.status(addStatus)
            }
            return
        }
        guard status == errSecSuccess else { throw SpeechKeyStoreError.status(status) }
    }

    public func deleteElevenLabsAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SpeechKeyStoreError.status(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]
    }
}

public final class InMemorySpeechKeyStore: SpeechKeyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var key: String?

    public init(key: String? = nil) {
        self.key = key
    }

    public func elevenLabsAPIKey() throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return key
    }

    public func setElevenLabsAPIKey(_ key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        self.key = key.isEmpty ? nil : key
    }

    public func deleteElevenLabsAPIKey() throws {
        lock.lock()
        defer { lock.unlock() }
        key = nil
    }
}

public enum SpeechKeyStoreError: LocalizedError {
    case status(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .status(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain operation failed: \(message)"
            }
            return "Keychain operation failed with status \(status)"
        }
    }
}
