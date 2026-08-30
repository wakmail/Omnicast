// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public enum NotesLauncherPresentation {
    @MainActor
    public static func presenters(store: NotesStore) -> [String: LauncherCommandPresenter] {
        [
            SearchNotesCommand().id: { _, query in
                presentedView(store: store, selectedNoteID: nil, initialQuery: query)
            },
            "notes.open": { command, _ in
                let noteID = (command as? OpenNoteCommand)?.note.id
                return presentedView(store: store, selectedNoteID: noteID)
            }
        ]
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
