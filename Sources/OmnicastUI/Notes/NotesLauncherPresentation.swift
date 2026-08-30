// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public enum NotesLauncherPresentation {
    @MainActor
    public static func presenters(store: NotesStore) -> [String: LauncherCommandPresenter] {
        var result: [String: LauncherCommandPresenter] = [
            SearchNotesCommand().id: { query in
                presentedView(store: store, selectedNoteID: nil, initialQuery: query)
            }
        ]
        for note in store.notes {
            result[OpenNoteCommand.commandID(for: note.id)] = { _ in
                presentedView(store: store, selectedNoteID: note.id)
            }
        }
        return result
    }

    @MainActor
    public static func presentedView(
        store: NotesStore,
        selectedNoteID: UUID? = nil,
        initialQuery: String = ""
    ) -> LauncherPresentedView {
        let model = NotesManagerViewModel(
            store: store,
            selectedNoteID: selectedNoteID,
            initialQuery: initialQuery
        )
        return LauncherPresentedView(
            title: selectedNoteID == nil ? "Notes" : model.selectedNote?.title ?? "Notes",
            content: AnyView(NotesManagerView(viewModel: model)),
            showsSearchField: false,
            initialQuery: "",
            onDismiss: { [weak model] in model?.flushCurrentNote() }
        )
    }
}
