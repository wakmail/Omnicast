// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

public enum LauncherKey: Equatable, Sendable {
    case moveUp
    case moveDown
    case enter
    case commandEnter
    case escape
    case actions
    case settings
}

public struct RoutedLauncherKey: Identifiable, Sendable {
    public let id = UUID()
    public let key: LauncherKey

    public init(_ key: LauncherKey) {
        self.key = key
    }
}

@MainActor
public final class LauncherKeyEvents: ObservableObject {
    @Published public private(set) var latest: RoutedLauncherKey?

    public init() {}

    public func send(_ key: LauncherKey) {
        latest = RoutedLauncherKey(key)
    }
}
