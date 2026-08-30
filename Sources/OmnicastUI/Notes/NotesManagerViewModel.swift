// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import OmnicastCore

@MainActor
public final class NotesManagerViewModel: ObservableObject {
    @Published public var query = "" {
        didSet { refreshVisibleNotes() }
    }
    @Published public private(set) var visibleNotes: [Note] = []
    @Published public private(set) var selectedNoteID: UUID?
    @Published public var draft = "" {
        didSet { draftDidChange() }
    }
    @Published public var usesMonospacedFont = false
    @Published public private(set) var errorMessage: String?

    public let store: NotesStore

    private var isLoadingDraft = false
    private var subscriptions = Set<AnyCancellable>()

    public init(
        store: NotesStore,
        selectedNoteID: UUID? = nil,
        initialQuery: String = ""
    ) {
        self.store = store
        query = initialQuery

        store.$notes
            .sink { [weak self] _ in self?.refreshVisibleNotes() }
            .store(in: &subscriptions)
        store.$autosaveError
            .sink { [weak self] in self?.errorMessage = $0 }
            .store(in: &subscriptions)

        refreshVisibleNotes(preferredSelection: selectedNoteID)
    }

    public var selectedNote: Note? {
        guard let selectedNoteID else { return nil }
        return store.note(id: selectedNoteID)
    }

    public func select(_ id: UUID) {
        guard id != selectedNoteID, let note = store.note(id: id) else { return }
        flushCurrentNote()
        selectedNoteID = id
        loadDraft(note.body)
    }

    public func createNote() {
        flushCurrentNote()
        do {
            let note = try store.create()
            query = ""
            selectedNoteID = note.id
            loadDraft(note.body)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteSelectedNote() {
        guard let selectedNoteID else { return }
        do {
            _ = try store.delete(id: selectedNoteID)
            let next = visibleNotes.first
            self.selectedNoteID = next?.id
            loadDraft(next?.body ?? "")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func togglePinSelectedNote() {
        guard let selectedNoteID else { return }
        do {
            _ = try store.togglePin(id: selectedNoteID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func flushCurrentNote() {
        guard let selectedNoteID else { return }
        do {
            try store.flushAutosave(id: selectedNoteID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshVisibleNotes(preferredSelection: UUID? = nil) {
        visibleNotes = store.search(query)
        let preferred = preferredSelection ?? selectedNoteID
        if let preferred, visibleNotes.contains(where: { $0.id == preferred }) {
            if selectedNoteID != preferred {
                selectedNoteID = preferred
                loadDraft(store.note(id: preferred)?.body ?? "")
            }
            return
        }

        selectedNoteID = visibleNotes.first?.id
        loadDraft(visibleNotes.first?.body ?? "")
    }

    private func loadDraft(_ body: String) {
        isLoadingDraft = true
        draft = body
        isLoadingDraft = false
    }

    private func draftDidChange() {
        guard !isLoadingDraft, let selectedNoteID else { return }
        store.scheduleAutosave(id: selectedNoteID, body: draft)
    }
}
