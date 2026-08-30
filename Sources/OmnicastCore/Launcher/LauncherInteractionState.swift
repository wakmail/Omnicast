// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum LauncherEscapeAction: Equatable, Sendable {
    case pop
    case hide
}

public struct LauncherNavigationStack<Destination> {
    public private(set) var destinations: [Destination]

    public init(destinations: [Destination] = []) {
        self.destinations = destinations
    }

    public var isRoot: Bool { destinations.isEmpty }
    public var current: Destination? { destinations.last }
    public var depth: Int { destinations.count }

    public mutating func push(_ destination: Destination) {
        destinations.append(destination)
    }

    @discardableResult
    public mutating func pop() -> Destination? {
        destinations.popLast()
    }

    public mutating func handleEscape() -> LauncherEscapeAction {
        guard pop() != nil else { return .hide }
        return .pop
    }

    public mutating func removeAll() {
        destinations.removeAll()
    }
}

extension LauncherNavigationStack: Equatable where Destination: Equatable {}

public struct LauncherArgumentDefinition: Equatable, Sendable {
    public let name: String
    public let placeholder: String
    public let isRequired: Bool

    public init(name: String, placeholder: String, isRequired: Bool) {
        self.name = name
        self.placeholder = placeholder
        self.isRequired = isRequired
    }
}

public enum LauncherArgumentSubmission: Equatable, Sendable {
    case needsValue(String)
    case next(LauncherArgumentDefinition)
    case complete([String: String])
}

public struct LauncherArgumentState: Equatable, Sendable {
    public let definitions: [LauncherArgumentDefinition]
    public private(set) var currentIndex: Int
    public private(set) var values: [String: String]

    public init(definitions: [LauncherArgumentDefinition]) {
        self.definitions = definitions
        currentIndex = 0
        values = [:]
    }

    public var current: LauncherArgumentDefinition? {
        guard definitions.indices.contains(currentIndex) else { return nil }
        return definitions[currentIndex]
    }

    public var progress: String {
        guard !definitions.isEmpty else { return "" }
        return "Argument \(min(currentIndex + 1, definitions.count)) of \(definitions.count)"
    }

    public mutating func submit(
        _ value: String,
        allowingEmpty: Bool = false
    ) -> LauncherArgumentSubmission {
        guard let current else { return .complete(values) }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isRequired, trimmed.isEmpty {
            return .needsValue(current.placeholder)
        }
        if !allowingEmpty, trimmed.isEmpty, current.isRequired {
            return .needsValue(current.placeholder)
        }
        values[current.name] = value
        currentIndex += 1
        if let next = self.current {
            return .next(next)
        }
        return .complete(values)
    }
}

public enum LauncherInputMode: Equatable, Sendable {
    case browsing
    case argument(placeholder: String, progress: String)
    case confirmation(commandTitle: String)
}
