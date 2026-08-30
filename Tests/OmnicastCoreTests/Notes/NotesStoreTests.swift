// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

@MainActor
final class NotesStoreTests: XCTestCase {
    func testCRUDPersistsMarkdownDocumentsAndIndex() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let updated = created.addingTimeInterval(60)
        let store = try NotesStore(directoryURL: directory)

        let note = try store.create(body: "# First\nBody", at: created)

        XCTAssertEqual(note.title, "First")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.indexFileURL.path))
        XCTAssertEqual(
            try String(contentsOf: store.noteFileURL(id: note.id), encoding: .utf8),
            "# First\nBody"
        )

        let changed = try store.update(id: note.id, body: "Second\nChanged", at: updated)
        XCTAssertEqual(changed?.title, "Second")
        XCTAssertEqual(changed?.updated, updated)
        XCTAssertEqual(try store.togglePin(id: note.id, at: updated)?.pinned, true)

        let loaded = try NotesStore(directoryURL: directory)
        XCTAssertEqual(loaded.note(id: note.id)?.body, "Second\nChanged")
        XCTAssertEqual(loaded.note(id: note.id)?.created, created)
        XCTAssertEqual(loaded.note(id: note.id)?.pinned, true)

        XCTAssertTrue(try loaded.delete(id: note.id))
        XCTAssertFalse(try loaded.delete(id: note.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: loaded.noteFileURL(id: note.id).path))
    }

    func testSearchMatchesTitleBodyCaseAndAllTokens() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try NotesStore(directoryURL: directory)
        let first = try store.create(body: "Project Atlas\nLaunch checklist and owners")
        _ = try store.create(body: "Recipes\nTomato soup")

        XCTAssertEqual(store.search("ATLAS").map(\.id), [first.id])
        XCTAssertEqual(store.search("launch owners").map(\.id), [first.id])
        XCTAssertTrue(store.search("launch soup").isEmpty)
        XCTAssertEqual(store.search(" ").count, 2)
    }

    func testPinnedNotesSortBeforeRecentlyUpdatedNotes() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try NotesStore(directoryURL: directory)
        let old = try store.create(body: "Pinned", at: Date(timeIntervalSince1970: 100))
        let recent = try store.create(body: "Recent", at: Date(timeIntervalSince1970: 200))

        _ = try store.togglePin(id: old.id, at: Date(timeIntervalSince1970: 150))

        XCTAssertEqual(store.notes.map(\.id), [old.id, recent.id])
    }

    func testAutosaveWaitsForFlushAndSavesLatestBody() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try NotesStore(directoryURL: directory)
        let note = try store.create(body: "Original")

        store.scheduleAutosave(id: note.id, body: "First", delay: .seconds(30))
        store.scheduleAutosave(id: note.id, body: "Latest", delay: .seconds(30))

        XCTAssertEqual(store.note(id: note.id)?.body, "Original")
        try store.flushAutosave(id: note.id, at: Date(timeIntervalSince1970: 500))
        XCTAssertEqual(store.note(id: note.id)?.body, "Latest")
        XCTAssertEqual(
            try String(contentsOf: store.noteFileURL(id: note.id), encoding: .utf8),
            "Latest"
        )
    }
}
