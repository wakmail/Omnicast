// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import XCTest

final class ScriptCommandParserTests: XCTestCase {
    func testParsesBashScriptCommandHeader() throws {
        let source = """
        #!/bin/bash
        # Required parameters:
        # @raycast.schemaVersion 1
        # @raycast.title Search Pull Requests
        # @raycast.mode inline

        # Optional parameters:
        # @raycast.packageName GitHub Utilities
        # @raycast.icon 🔎
        # @raycast.argument1 {"type":"text","placeholder":"Repository","required":true}
        # @raycast.argument2 {"type":"dropdown","placeholder":"State","optional":true,"data":[{"title":"Open","value":"open"}]}
        # @raycast.needsConfirmation yes
        # @raycast.refreshTime 5s
        """
        let url = URL(fileURLWithPath: "/tmp/github/search.sh")

        let command = try XCTUnwrap(ScriptCommandParser.parse(source: source, scriptURL: url))

        XCTAssertEqual(command.title, "Search Pull Requests")
        XCTAssertEqual(command.mode, .inline)
        XCTAssertEqual(command.packageName, "GitHub Utilities")
        XCTAssertEqual(command.icon, "🔎")
        XCTAssertEqual(command.refreshTime, "10s")
        XCTAssertEqual(command.refreshInterval, 10)
        XCTAssertTrue(command.needsConfirmation)
        XCTAssertEqual(command.arguments.count, 2)
        XCTAssertTrue(command.arguments[0].required)
        XCTAssertEqual(command.arguments[1].type, .dropdown)
        XCTAssertFalse(command.arguments[1].required)
        XCTAssertEqual(command.arguments[1].options, [ScriptArgumentOption(title: "Open", value: "open")])
    }

    func testParsesJavaScriptCommentsAndDowngradesUnrefreshableInlineMode() throws {
        let source = """
        #!/usr/bin/env node
        // @raycast.schemaVersion 1
        // @raycast.title Current Track
        // @raycast.mode inline
        // @raycast.argument1 {"type":"password","placeholder":"Token","percentEncoded":true}
        """
        let command = try XCTUnwrap(
            ScriptCommandParser.parse(
                source: source,
                scriptURL: URL(fileURLWithPath: "/tmp/music/current.js")
            )
        )

        XCTAssertEqual(command.mode, .compact)
        XCTAssertEqual(command.packageName, "music")
        XCTAssertEqual(command.arguments.first?.type, .password)
        XCTAssertTrue(command.arguments.first?.percentEncoded == true)
    }

    func testRejectsMissingSchemaAndUnsupportedMode() {
        let url = URL(fileURLWithPath: "/tmp/example.sh")
        XCTAssertNil(
            ScriptCommandParser.parse(
                source: "# @raycast.title Example\n# @raycast.mode compact",
                scriptURL: url
            )
        )
        XCTAssertNil(
            ScriptCommandParser.parse(
                source: "# @raycast.schemaVersion 1\n# @raycast.title Example\n# @raycast.mode detail",
                scriptURL: url
            )
        )
    }
}
