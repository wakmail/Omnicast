// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

@MainActor
final class NotesCommandsProviderTests: XCTestCase {
    func testProviderIncludesSearchAndOneCommandPerNote() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try NotesStore(directoryURL: directory)
        let first = try store.create(body: "First Note\nBody")
        let second = try store.create(body: "Second Note\nBody")
        let commands = await NotesCommandsProvider(store: store).commands()

        XCTAssertEqual(commands.first?.id, SearchNotesCommand().id)
        XCTAssertEqual(
            Set(commands.dropFirst().map(\.id)),
            Set([
                OpenNoteCommand.commandID(for: first.id),
                OpenNoteCommand.commandID(for: second.id)
            ])
        )
        XCTAssertEqual(Set(commands.dropFirst().map(\.title)), ["First Note", "Second Note"])
    }
}
