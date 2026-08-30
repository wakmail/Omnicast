// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct SearchNotesCommand: ViewPresentingCommand {
    public let id = "notes.search"
    public let title = "Search Notes"
    public let subtitle = "Browse and edit notes"
    public let icon = CommandIcon.sfSymbol("note.text")
    public let keywords = ["notes", "markdown", "write", "editor"]
    public let kind = CommandKind.system

    public init() {}

    @MainActor
    public func execute(context: CommandContext) async throws {}
}

public struct OpenNoteCommand: ViewPresentingCommand {
    public let note: Note

    public var id: String { Self.commandID(for: note.id) }
    public var title: String { note.title }
    public var subtitle: String { note.body }
    public var icon: CommandIcon { .sfSymbol(note.pinned ? "pin.fill" : "note.text") }
    public var keywords: [String] { ["note", "markdown", note.body] }
    public var kind: CommandKind { .system }
    public var resourceURL: URL? { nil }
    public var presentationID: String { "notes.open" }

    public init(note: Note) {
        self.note = note
    }

    public static func commandID(for noteID: UUID) -> String {
        "notes.open.\(noteID.uuidString)"
    }

    @MainActor
    public func execute(context: CommandContext) async throws {}
}

public struct NotesCommandsProvider: CommandProvider {
    private let store: NotesStore

    @MainActor
    public init(store: NotesStore) {
        self.store = store
    }

    public func commands() async -> [any Command] {
        let notes = await MainActor.run { store.notes }
        return [SearchNotesCommand()] + notes.map(OpenNoteCommand.init)
    }
}
