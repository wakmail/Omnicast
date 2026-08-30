// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore

@MainActor
public final class MenuSearchViewModel: ObservableObject {
    @Published public private(set) var applicationName = "Application"
    @Published public private(set) var visibleItems: [MenuItemEntry] = []
    @Published public private(set) var selectedIndex = 0
    @Published public private(set) var errorMessage: String?

    private let index: MenuItemIndex
    private let onDismiss: () -> Void
    private var allItems: [MenuItemEntry] = []
    private var query = ""

    public init(index: MenuItemIndex, onDismiss: @escaping () -> Void = {}) {
        self.index = index
        self.onDismiss = onDismiss
        reload()
    }

    public var selectedItem: MenuItemEntry? {
        guard visibleItems.indices.contains(selectedIndex) else { return nil }
        return visibleItems[selectedIndex]
    }

    public var isAccessibilityGranted: Bool {
        index.isAccessibilityGranted
    }

    public func reload() {
        do {
            let snapshot = try index.read()
            applicationName = snapshot.applicationName
            allItems = snapshot.items
            errorMessage = nil
            refresh()
        } catch {
            allItems = []
            visibleItems = []
            selectedIndex = 0
            errorMessage = error.localizedDescription
        }
    }

    public func updateQuery(_ value: String) {
        query = value
        refresh()
    }

    public func select(_ value: Int) {
        guard visibleItems.indices.contains(value) else { return }
        selectedIndex = value
    }

    @discardableResult
    public func handle(_ key: LauncherKey) -> Bool {
        switch key {
        case .moveUp:
            selectedIndex = max(0, selectedIndex - 1)
        case .moveDown:
            selectedIndex = min(max(0, visibleItems.count - 1), selectedIndex + 1)
        case .enter:
            pressSelected()
        default:
            return false
        }
        return true
    }

    public func pressSelected() {
        guard let selectedItem, selectedItem.isEnabled else { return }
        onDismiss()
        Task {
            do {
                try await index.press(selectedItem)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refresh() {
        let selectedPath = selectedItem?.fullPath
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            visibleItems = allItems
        } else {
            visibleItems = allItems.filter { item in
                item.fullPath.range(
                    of: normalized,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
            }
        }
        if let selectedPath,
           let position = visibleItems.firstIndex(where: { $0.fullPath == selectedPath }) {
            selectedIndex = position
        } else {
            selectedIndex = 0
        }
    }
}
