// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

@MainActor
final class RestoringPasteServiceTests: XCTestCase {
    func testPasteRestoresEveryPasteboardItem() async throws {
        let original = PasteboardSnapshot(items: [
            .init(values: ["public.utf8-plain-text": Data("before".utf8)]),
            .init(values: ["public.png": Data([1, 2, 3])])
        ])
        let pasteboard = FakePasteboard(snapshot: original)
        let poster = FakeEventPoster()
        let service = RestoringPasteService(
            pasteboard: pasteboard,
            eventPoster: poster,
            restorationDelay: 0
        )

        try await service.paste("transcript")

        XCTAssertEqual(pasteboard.writtenText, "transcript")
        XCTAssertEqual(pasteboard.restoredSnapshot, original)
        XCTAssertEqual(poster.postCount, 1)
    }

    func testPasteRestoresAfterEventFailure() async {
        let original = PasteboardSnapshot(items: [
            .init(values: ["public.text": Data("before".utf8)])
        ])
        let pasteboard = FakePasteboard(snapshot: original)
        let poster = FakeEventPoster(error: TestError.event)
        let service = RestoringPasteService(
            pasteboard: pasteboard,
            eventPoster: poster,
            restorationDelay: 0
        )

        do {
            try await service.paste("transcript")
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? TestError, .event)
        }
        XCTAssertEqual(pasteboard.restoredSnapshot, original)
    }
}

@MainActor
private final class FakePasteboard: RestorablePasteboard {
    let initialSnapshot: PasteboardSnapshot
    var writtenText: String?
    var restoredSnapshot: PasteboardSnapshot?

    init(snapshot: PasteboardSnapshot) {
        initialSnapshot = snapshot
    }

    func snapshot() -> PasteboardSnapshot {
        initialSnapshot
    }

    func writeString(_ text: String) -> Bool {
        writtenText = text
        return true
    }

    func restore(_ snapshot: PasteboardSnapshot) {
        restoredSnapshot = snapshot
    }
}

@MainActor
private final class FakeEventPoster: PasteKeyboardEventPosting {
    var postCount = 0
    let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func postPaste() throws {
        postCount += 1
        if let error { throw error }
    }
}

private enum TestError: Error, Equatable {
    case event
}
