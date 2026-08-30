// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class WebSearchBangsTests: XCTestCase {
    func testResolvesSeedBangsAndAliases() {
        let resolver = WebSearchBangs()

        XCTAssertEqual(
            resolver.resolve(query: "!g swift actors")?.absoluteString,
            "https://www.google.com/search?q=swift%20actors"
        )
        XCTAssertEqual(
            resolver.resolve(query: "!youtube jazz")?.absoluteString,
            "https://www.youtube.com/results?search_query=jazz"
        )
        XCTAssertEqual(
            resolver.resolve(query: "!gh C++")?.absoluteString,
            "https://github.com/search?q=C%2B%2B"
        )
    }

    func testUsesDefaultSearchForPlainAndUnknownBangQueries() {
        let resolver = WebSearchBangs(
            defaultSearchURLTemplate: "https://search.example/?q={query}"
        )

        XCTAssertEqual(
            resolver.resolve(query: "native mac apps")?.absoluteString,
            "https://search.example/?q=native%20mac%20apps"
        )
        XCTAssertEqual(
            resolver.resolve(query: "!unknown value")?.absoluteString,
            "https://search.example/?q=%21unknown%20value"
        )
        XCTAssertNil(resolver.resolve(query: "   "))
    }

    func testIncludesCompleteUpstreamSeedCatalog() {
        let resolver = WebSearchBangs()
        let expected = ["g", "ddg", "yt", "gh", "npm", "mdn", "maps", "img", "wiki", "x"]

        XCTAssertEqual(WebSearchBangs.defaultBangs.map(\.key), expected)
        XCTAssertNotNil(resolver.bang(for: "!wikipedia"))
        XCTAssertNotNil(resolver.bang(for: "gimages"))
    }
}
