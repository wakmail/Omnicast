// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import OmnicastCore
import SwiftUI

@MainActor
public struct LauncherPresentedView {
    public let title: String
    public let content: AnyView
    public let showsSearchField: Bool
    public let initialQuery: String?
    public let onQueryChange: (String) -> Void
    public let onKey: (LauncherKey) -> Bool
    public let onDismiss: () -> Void

    public init(
        title: String,
        content: AnyView,
        showsSearchField: Bool = true,
        initialQuery: String? = nil,
        onQueryChange: @escaping (String) -> Void = { _ in },
        onKey: @escaping (LauncherKey) -> Bool = { _ in false },
        onDismiss: @escaping () -> Void = {}
    ) {
        self.title = title
        self.content = content
        self.showsSearchField = showsSearchField
        self.initialQuery = initialQuery
        self.onQueryChange = onQueryChange
        self.onKey = onKey
        self.onDismiss = onDismiss
    }
}

public typealias LauncherCommandPresenter = @MainActor (
    any ViewPresentingCommand,
    String
) -> LauncherPresentedView

@MainActor
public final class LauncherNavigationCoordinator: ObservableObject {
    public enum Action {
        case push(LauncherPresentedView)
        case pop
        case reset
        case reloadCommands
    }

    public struct RoutedAction: Identifiable {
        public let id = UUID()
        public let action: Action
    }

    @Published public private(set) var latest: RoutedAction?

    public init() {}

    public func push(_ view: LauncherPresentedView) {
        latest = RoutedAction(action: .push(view))
    }

    public func pop() {
        latest = RoutedAction(action: .pop)
    }

    public func reset() {
        latest = RoutedAction(action: .reset)
    }

    public func reloadCommands() {
        latest = RoutedAction(action: .reloadCommands)
    }
}
