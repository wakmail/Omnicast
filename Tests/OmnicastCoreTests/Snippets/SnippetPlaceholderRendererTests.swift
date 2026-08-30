// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

final class SnippetPlaceholderRendererTests: XCTestCase {
    private let uuid = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!

    func testRendersEveryRequiredPlaceholder() {
        let result = SnippetPlaceholderRenderer.render(
            "{clipboard}|{selection}|{date:YYYY-MM-DD}|{time:HH:mm:ss}|{uuid}|{random:UUID}",
            context: context()
        )

        XCTAssertEqual(
            result.text,
            "Copied|Chosen|2023-11-14|22:13:20|12345678-1234-1234-1234-123456789ABC|12345678-1234-1234-1234-123456789ABC"
        )
        XCTAssertNil(result.cursorOffsetFromEnd)
    }

    func testReportsCursorDistanceAndRemovesEveryCursorToken() {
        let result = SnippetPlaceholderRenderer.render(
            "👋{cursor}middle{cursor-position}end",
            context: context()
        )

        XCTAssertEqual(result.text, "👋middleend")
        XCTAssertEqual(result.cursorOffsetFromEnd, 9)
    }

    func testLeavesUnknownPlaceholderUntouched() {
        let result = SnippetPlaceholderRenderer.render(
            "Keep {argument} and {other}",
            context: context()
        )

        XCTAssertEqual(result.text, "Keep {argument} and {other}")
    }

    func testLocaleDateAndTimeAreDeterministicFromContext() {
        let result = SnippetPlaceholderRenderer.render(
            "{date} {time}",
            context: context()
        )

        XCTAssertEqual(result.text, "11/14/23 10:13:20\u{202F}PM")
    }

    private func context() -> SnippetPlaceholderContext {
        SnippetPlaceholderContext(
            clipboard: "Copied",
            selection: "Chosen",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(secondsFromGMT: 0)!,
            uuid: uuid
        )
    }
}
