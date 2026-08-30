// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore

@MainActor
public final class EmojiGridViewModel: ObservableObject {
    @Published public private(set) var emojis: [EmojiEntry] = []
    @Published public private(set) var selectedIndex = 0
    @Published public private(set) var errorMessage: String?

    public let columnCount: Int

    private let store: EmojiStore
    private let pasteService: EmojiPasteService
    private let onDismiss: () -> Void

    public init(
        store: EmojiStore,
        pasteService: EmojiPasteService,
        columnCount: Int = 8,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.store = store
        self.pasteService = pasteService
        self.columnCount = max(1, columnCount)
        self.onDismiss = onDismiss
        emojis = store.search("")
    }

    public var selectedEmoji: EmojiEntry? {
        guard emojis.indices.contains(selectedIndex) else { return nil }
        return emojis[selectedIndex]
    }

    public func updateQuery(_ query: String) {
        let selectedValue = selectedEmoji?.emoji
        emojis = store.search(query)
        if let selectedValue,
           let index = emojis.firstIndex(where: { $0.emoji == selectedValue }) {
            selectedIndex = index
        } else {
            selectedIndex = 0
        }
    }

    public func select(_ index: Int) {
        guard emojis.indices.contains(index) else { return }
        selectedIndex = index
    }

    @discardableResult
    public func handle(_ key: LauncherKey) -> Bool {
        switch key {
        case .moveUp:
            move(by: 0 - columnCount)
        case .moveDown:
            move(by: columnCount)
        case .enter:
            pasteSelected()
        default:
            return false
        }
        return true
    }

    public func moveLeft() { move(by: -1) }
    public func moveRight() { move(by: 1) }
    public func moveUp() { move(by: 0 - columnCount) }
    public func moveDown() { move(by: columnCount) }

    public func pasteSelected() {
        guard let selectedEmoji else { return }
        onDismiss()
        Task {
            do {
                try await pasteService.paste(selectedEmoji.emoji)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func move(by offset: Int) {
        guard !emojis.isEmpty else { return }
        selectedIndex = min(max(0, selectedIndex + offset), emojis.count - 1)
    }
}
