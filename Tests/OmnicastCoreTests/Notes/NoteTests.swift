// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class NoteTests: XCTestCase {
    func testTitleUsesFirstLineAndRemovesMarkdownHeadingMarkers() {
        XCTAssertEqual(Note.title(from: "# Project Atlas\nDetails"), "Project Atlas")
        XCTAssertEqual(Note.title(from: "###   Weekly Plan  \nDetails"), "Weekly Plan")
        XCTAssertEqual(Note.title(from: "Plain title\nDetails"), "Plain title")
    }

    func testTitleFallsBackWhenFirstLineIsEmpty() {
        XCTAssertEqual(Note.title(from: ""), "Untitled Note")
        XCTAssertEqual(Note.title(from: "\nContent begins later"), "Untitled Note")
        XCTAssertEqual(Note.title(from: "###   \nContent"), "Untitled Note")
    }
}
