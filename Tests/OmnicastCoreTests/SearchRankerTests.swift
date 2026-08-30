// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

final class SearchRankerTests: XCTestCase {
    func testMoreCompactPrefixRanksFirst() {
        let commands: [any Command] = [
            TestCommand(id: "calculator", title: "Calculator"),
            TestCommand(id: "calendar", title: "Calendar")
        ]

        let ranked = SearchRanker.rank(commands, query: "cal")

        XCTAssertEqual(ranked.map { $0.command.id }, ["calendar", "calculator"])
    }

    func testInitialsMatch() {
        let commands: [any Command] = [
            TestCommand(id: "visual", title: "Visual Studio Code"),
            TestCommand(id: "voice", title: "Voice Memos")
        ]

        let ranked = SearchRanker.rank(commands, query: "vsc")

        XCTAssertEqual(ranked.map { $0.command.id }, ["visual"])
    }

    func testEmptyQueryUsesFrecency() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let commands: [any Command] = [
            TestCommand(id: "older", title: "Older"),
            TestCommand(id: "frequent", title: "Frequent")
        ]
        let entries = [
            "older": FrecencyEntry(useCount: 1, lastUsedAt: now, score: 1),
            "frequent": FrecencyEntry(useCount: 8, lastUsedAt: now, score: 8)
        ]

        let ranked = SearchRanker.rank(commands, query: "", frecency: entries, now: now)

        XCTAssertEqual(ranked.map { $0.command.id }, ["frequent", "older"])
    }
}
