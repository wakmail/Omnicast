// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public protocol CommandProvider: Sendable {
    func commands() async -> [any Command]
}

public actor CommandRegistry {
    private let providers: [any CommandProvider]
    private var cachedCommands: [any Command]?

    public init(providers: [any CommandProvider]) {
        self.providers = providers
    }

    public func commands(forceRefresh: Bool = false) async -> [any Command] {
        if !forceRefresh, let cachedCommands {
            return cachedCommands
        }

        var seen = Set<String>()
        var result: [any Command] = []
        for provider in providers {
            for command in await provider.commands() where seen.insert(command.id).inserted {
                result.append(command)
            }
        }
        cachedCommands = result
        return result
    }

    public func invalidate() {
        cachedCommands = nil
    }
}
