// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class EmojiStoreTests: XCTestCase {
    func testSearchRanksNameThenKeywordMatches() {
        let exact = EmojiEntry(name: "fire", emoji: "🔥", keywords: ["flame"])
        let prefix = EmojiEntry(name: "fire_engine", emoji: "🚒", keywords: ["truck"])
        let keyword = EmojiEntry(name: "heart", emoji: "❤️", keywords: ["fire"])
        let keywordPrefix = EmojiEntry(name: "sparkles", emoji: "✨", keywords: ["firework"])
        let substring = EmojiEntry(name: "campfire", emoji: "🏕️", keywords: [])
        let store = EmojiStore(entries: [substring, keywordPrefix, keyword, prefix, exact])

        XCTAssertEqual(
            store.search("fire").map(\.emoji),
            ["🔥", "🚒", "✨", "❤️", "🏕️"]
        )
    }

    func testSearchTransliteratesQueryAndData() {
        let store = EmojiStore(entries: [
            EmojiEntry(name: "ulybka", emoji: "🙂"),
            EmojiEntry(name: "кошка", emoji: "🐈")
        ])

        XCTAssertEqual(store.search("улыбка").first?.emoji, "🙂")
        XCTAssertEqual(store.search("koska").first?.emoji, "🐈")
    }

    func testDecodesCompactFixtureData() throws {
        let data = Data(#"[{"n":"wave","e":"👋","k":["hello"]}]"#.utf8)
        let store = try EmojiStore(data: data)

        XCTAssertEqual(store.entries, [EmojiEntry(name: "wave", emoji: "👋", keywords: ["hello"])])
    }

    func testLoadsBundledUpstreamData() throws {
        let store = try EmojiStore()

        XCTAssertGreaterThan(store.entries.count, 1_000)
        XCTAssertEqual(store.search("grinning").first?.emoji, "😀")
    }
}
