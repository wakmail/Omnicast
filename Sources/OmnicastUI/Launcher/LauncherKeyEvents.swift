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

public enum LauncherKeySurface: Equatable, Sendable {
    case rootList
    case pushedView
}

@MainActor
public final class LauncherKeyEvents: ObservableObject {
    @Published public private(set) var latest: RoutedLauncherKey?
    @Published public private(set) var activeSurface: LauncherKeySurface = .rootList
    private var pushedViewHandler: ((LauncherKey) -> Bool)?

    public init() {}

    public func send(_ key: LauncherKey) {
        latest = RoutedLauncherKey(key)
    }

    public func activateRootList() {
        pushedViewHandler = nil
        activeSurface = .rootList
    }

    public func activatePushedView(handler: @escaping (LauncherKey) -> Bool) {
        pushedViewHandler = handler
        activeSurface = .pushedView
    }

    @discardableResult
    public func route(_ key: LauncherKey) -> Bool {
        switch activeSurface {
        case .rootList:
            send(key)
            return true
        case .pushedView:
            return pushedViewHandler?(key) ?? false
        }
    }
}
