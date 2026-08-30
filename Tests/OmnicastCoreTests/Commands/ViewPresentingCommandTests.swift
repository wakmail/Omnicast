// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class ViewPresentingCommandTests: XCTestCase {
    func testDynamicNotesUseStablePresentationRoute() {
        let first = OpenNoteCommand(note: Note(body: "First\nOne"))
        let second = OpenNoteCommand(note: Note(body: "Second\nTwo"))

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.presentationID, "notes.open")
        XCTAssertEqual(second.presentationID, "notes.open")
    }

    func testStaticPresenterUsesItsCommandIdentifier() {
        let command = SearchEmojiCommand()

        XCTAssertEqual(command.presentationID, command.id)
    }
}
