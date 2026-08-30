// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import XCTest

final class SnippetKeywordMatcherTests: XCTestCase {
    func testMatchesImmediatelyUsingLowercaseComparison() {
        var matcher = SnippetKeywordMatcher(keywords: ["BRB"])

        XCTAssertNil(matcher.process("b"))
        XCTAssertNil(matcher.process("R"))
        XCTAssertEqual(
            matcher.process("b"),
            SnippetKeywordMatch(keyword: "brb", delimiter: "")
        )
    }

    func testKeywordSymbolsAreTokenCharacters() {
        var matcher = SnippetKeywordMatcher(keywords: [";email"])

        var result: SnippetKeywordMatch?
        for character in ";email" {
            result = matcher.process(character) ?? result
        }

        XCTAssertEqual(result?.keyword, ";email")
    }

    func testRetainsOnlyTheLongestPossibleSuffix() {
        var matcher = SnippetKeywordMatcher(keywords: ["abc"])

        for character in "xxab" {
            XCTAssertNil(matcher.process(character))
        }
        XCTAssertEqual(matcher.process("c")?.keyword, "abc")
    }

    func testBackspaceRemovesTheLastBufferedCharacter() {
        var matcher = SnippetKeywordMatcher(keywords: ["abc"])
        XCTAssertNil(matcher.process("a"))
        XCTAssertNil(matcher.process("b"))
        matcher.processBackspace()
        XCTAssertNil(matcher.process("b"))
        XCTAssertEqual(matcher.process("c")?.keyword, "abc")
    }

    func testUnknownCharacterResetsTheToken() {
        var matcher = SnippetKeywordMatcher(keywords: ["abc"])
        XCTAssertNil(matcher.process("a"))
        XCTAssertNil(matcher.process("💡"))
        XCTAssertNil(matcher.process("b"))
        XCTAssertNil(matcher.process("c"))
    }
}
