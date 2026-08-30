// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore

public enum ClipboardHistoryAction: Sendable {
    case moveSelectionUp
    case moveSelectionDown
    case pasteSelected
    case copySelected
    case togglePinSelected
    case deleteSelected
    case pasteVisibleItem(Int)
}

@MainActor
public final class ClipboardHistoryViewModel: ObservableObject {
    @Published public var query = "" {
        didSet { refreshVisibleItems() }
    }
    @Published public private(set) var visibleItems: [ClipboardItem] = []
    @Published public private(set) var selectedIndex = 0
    @Published public private(set) var errorMessage: String?

    private let store: ClipboardHistoryStore
    private let pasteService: PasteService
    private let onDismiss: () -> Void
    private var subscriptions = Set<AnyCancellable>()

    public init(
        store: ClipboardHistoryStore,
        pasteService: PasteService,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.store = store
        self.pasteService = pasteService
        self.onDismiss = onDismiss

        store.$items
            .sink { [weak self] items in
                self?.refreshVisibleItems(from: items)
            }
            .store(in: &subscriptions)
        refreshVisibleItems()
    }

    public var selectedItem: ClipboardItem? {
        guard visibleItems.indices.contains(selectedIndex) else { return nil }
        return visibleItems[selectedIndex]
    }

    public func select(_ index: Int) {
        guard visibleItems.indices.contains(index) else { return }
        selectedIndex = index
    }

    public func clearError() {
        errorMessage = nil
    }

    public func handle(_ action: ClipboardHistoryAction) {
        switch action {
        case .moveSelectionUp:
            selectedIndex = max(0, selectedIndex - 1)
        case .moveSelectionDown:
            selectedIndex = min(max(0, visibleItems.count - 1), selectedIndex + 1)
        case .pasteSelected:
            guard let selectedItem else { return }
            paste(selectedItem)
        case .copySelected:
            guard let selectedItem else { return }
            copy(selectedItem)
        case .togglePinSelected:
            guard let selectedItem else { return }
            do {
                try store.togglePin(id: selectedItem.id)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        case .deleteSelected:
            guard let selectedItem else { return }
            do {
                try store.delete(id: selectedItem.id)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        case .pasteVisibleItem(let index):
            guard visibleItems.indices.contains(index) else { return }
            paste(visibleItems[index])
        }
    }

    private func paste(_ item: ClipboardItem) {
        onDismiss()
        Task {
            do {
                try await pasteService.paste(item)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func copy(_ item: ClipboardItem) {
        do {
            try pasteService.copyOnly(item)
            errorMessage = nil
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshVisibleItems(from sourceItems: [ClipboardItem]? = nil) {
        let selectedID = selectedItem?.id
        let availableItems = sourceItems ?? store.items
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedQuery.isEmpty {
            visibleItems = availableItems
        } else {
            visibleItems = availableItems.filter { item in
                item.previewText.range(
                    of: normalizedQuery,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
            }
        }
        if let selectedID,
           let index = visibleItems.firstIndex(where: { $0.id == selectedID }) {
            selectedIndex = index
        } else {
            selectedIndex = min(selectedIndex, max(0, visibleItems.count - 1))
        }
    }
}
