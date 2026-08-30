// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Security

public protocol AIKeyStoring: Sendable {
    func apiKey(for provider: AIProviderIdentifier) throws -> String?
    func setAPIKey(_ key: String, for provider: AIProviderIdentifier) throws
    func deleteAPIKey(for provider: AIProviderIdentifier) throws
}

public final class AIKeyStore: AIKeyStoring, @unchecked Sendable {
    public static let service = "com.omnicast.ai"

    public init() {}

    public func apiKey(for provider: AIProviderIdentifier) throws -> String? {
        var query = baseQuery(for: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw AIKeyStoreError.status(status) }
        guard
            let data = result as? Data,
            let key = String(data: data, encoding: .utf8),
            !key.isEmpty
        else { return nil }
        return key
    }

    public func setAPIKey(_ key: String, for provider: AIProviderIdentifier) throws {
        guard !key.isEmpty else {
            try deleteAPIKey(for: provider)
            return
        }
        let data = Data(key.utf8)
        let query = baseQuery(for: provider)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw AIKeyStoreError.status(addStatus) }
            return
        }
        guard status == errSecSuccess else { throw AIKeyStoreError.status(status) }
    }

    public func deleteAPIKey(for provider: AIProviderIdentifier) throws {
        let status = SecItemDelete(baseQuery(for: provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AIKeyStoreError.status(status)
        }
    }

    private func baseQuery(for provider: AIProviderIdentifier) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: provider.rawValue
        ]
    }
}

public final class InMemoryAIKeyStore: AIKeyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var keys: [AIProviderIdentifier: String]

    public init(keys: [AIProviderIdentifier: String] = [:]) {
        self.keys = keys
    }

    public func apiKey(for provider: AIProviderIdentifier) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return keys[provider]
    }

    public func setAPIKey(_ key: String, for provider: AIProviderIdentifier) throws {
        lock.lock()
        defer { lock.unlock() }
        if key.isEmpty {
            keys.removeValue(forKey: provider)
        } else {
            keys[provider] = key
        }
    }

    public func deleteAPIKey(for provider: AIProviderIdentifier) throws {
        lock.lock()
        defer { lock.unlock() }
        keys.removeValue(forKey: provider)
    }
}

public enum AIKeyStoreError: LocalizedError {
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
