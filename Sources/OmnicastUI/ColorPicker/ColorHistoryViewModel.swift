// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore

@MainActor
public final class ColorHistoryViewModel: ObservableObject {
    @Published public private(set) var items: [ColorHistoryItem] = []
    @Published public private(set) var selectedIndex = 0
    @Published public private(set) var errorMessage: String?

    public let store: ColorHistoryStore

    private let clipboard: any ClipboardService
    private let onDismiss: () -> Void
    private var subscriptions = Set<AnyCancellable>()

    public init(
        store: ColorHistoryStore,
        clipboard: any ClipboardService,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.store = store
        self.clipboard = clipboard
        self.onDismiss = onDismiss
        items = store.items
        store.$items
            .sink { [weak self] in self?.items = $0 }
            .store(in: &subscriptions)
    }

    public var selectedItem: ColorHistoryItem? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    public func select(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selectedIndex = index
    }

    @discardableResult
    public func handle(_ key: LauncherKey) -> Bool {
        switch key {
        case .moveUp:
            selectedIndex = max(0, selectedIndex - 1)
        case .moveDown:
            selectedIndex = min(max(0, items.count - 1), selectedIndex + 1)
        case .enter:
            copySelected()
        default:
            return false
        }
        return true
    }

    public func copySelected() {
        guard let selectedItem else { return }
        clipboard.writeText(selectedItem.hex)
        errorMessage = nil
        onDismiss()
    }
}
