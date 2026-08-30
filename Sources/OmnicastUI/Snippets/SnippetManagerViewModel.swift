// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore

@MainActor
public final class SnippetManagerViewModel: ObservableObject {
    @Published public var query = "" {
        didSet { applySearch() }
    }
    @Published public private(set) var visibleSnippets: [Snippet] = []
    @Published public private(set) var selectedID: UUID?
    @Published public var name = ""
    @Published public var keyword = ""
    @Published public var content = ""
    @Published public private(set) var isCreating = false
    @Published public private(set) var errorMessage: String?

    private let store: SnippetStore
    private var allSnippets: [Snippet]
    private var subscriptions = Set<AnyCancellable>()

    public init(store: SnippetStore) {
        self.store = store
        allSnippets = store.snippets
        visibleSnippets = store.snippets
        store.$snippets
            .sink { [weak self] snippets in
                self?.receive(snippets)
            }
            .store(in: &subscriptions)
        if let first = visibleSnippets.first {
            select(first.id)
        } else {
            createNew()
        }
    }

    public func select(_ id: UUID) {
        guard let snippet = allSnippets.first(where: { $0.id == id }) else { return }
        selectedID = snippet.id
        name = snippet.name
        keyword = snippet.keyword ?? ""
        content = snippet.content
        isCreating = false
        errorMessage = nil
    }

    public func createNew() {
        selectedID = nil
        name = ""
        keyword = ""
        content = ""
        isCreating = true
        errorMessage = nil
    }

    public func save() {
        do {
            if let selectedID, !isCreating {
                _ = try store.update(
                    id: selectedID,
                    name: name,
                    keyword: keyword,
                    content: content
                )
            } else {
                let snippet = try store.create(
                    name: name,
                    keyword: keyword,
                    content: content
                )
                select(snippet.id)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteSelected() {
        guard let selectedID else { return }
        do {
            _ = try store.delete(id: selectedID)
            if let first = visibleSnippets.first {
                select(first.id)
            } else {
                createNew()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func receive(_ snippets: [Snippet]) {
        allSnippets = snippets
        applySearch()
        if let selectedID, let selected = snippets.first(where: { $0.id == selectedID }) {
            name = selected.name
            keyword = selected.keyword ?? ""
            content = selected.content
        }
    }

    private func applySearch() {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty {
            visibleSnippets = allSnippets
        } else {
            visibleSnippets = allSnippets.filter { snippet in
                snippet.name.localizedCaseInsensitiveContains(needle)
                    || snippet.content.localizedCaseInsensitiveContains(needle)
                    || snippet.keyword?.localizedCaseInsensitiveContains(needle) == true
            }
        }
    }
}
